"""CPU orthographic bind-pose preview. No engine, no animation/acceptance claims."""
import argparse, io, json, struct, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('output',type=Path);p.add_argument('--yaw',type=float,default=0,help='Preview-only yaw in degrees; source file is unchanged.');p.add_argument('--pitch',type=float,default=0,help='Preview-only pitch in degrees, applied after yaw.');a=p.parse_args()
raw=a.source.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=raw[28+n:]
def read(i):
 ac=doc['accessors'][i];assert 'sparse' not in ac;v=doc['bufferViews'][ac['bufferView']];width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[ac['type']];dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[ac['componentType']];dt=np.dtype(dtype)
 return np.ndarray((ac['count'],width),dtype=dt,buffer=binary,offset=v.get('byteOffset',0)+ac.get('byteOffset',0),strides=(v.get('byteStride',width*dt.itemsize),dt.itemsize)).copy()
def transform(node):
 if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
 x,y,z,w=node.get('rotation',[0,0,0,1]);r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
 m=np.eye(4);m[:3,:3]=r@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m
surfaces=[]
def visit(i,parent):
 node=doc['nodes'][i];world=parent@transform(node)
 if 'mesh' in node:
  for part in doc['meshes'][node['mesh']]['primitives']:
   assert part.get('mode',4)==4
   position=read(part['attributes']['POSITION']);position=(np.c_[position,np.ones(len(position))]@world.T)[:,:3]
   if a.yaw:
    angle=math.radians(a.yaw);c,s=math.cos(angle),math.sin(angle);position=position@np.array([[c,0,-s],[0,1,0],[s,0,c]])
   if a.pitch:
    angle=math.radians(a.pitch);c,s=math.cos(angle),math.sin(angle);position=position@np.array([[1,0,0],[0,c,s],[0,-s,c]])
   uv=read(part['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in part['attributes'] else np.zeros((len(position),2))
   indices=read(part['indices']).reshape(-1,3) if 'indices' in part else np.arange(len(position)).reshape(-1,3)
   material=doc.get('materials',[{}])[part.get('material',0)].get('pbrMetallicRoughness',{});factor=np.array(material.get('baseColorFactor',[1,1,1,1]))[:3]
   texture=np.full((1,1,3),255,dtype=np.uint8)
   if 'baseColorTexture' in material:
    image=doc['images'][doc['textures'][material['baseColorTexture']['index']]['source']];view=doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0);texture=np.array(Image.open(io.BytesIO(binary[start:start+view['byteLength']])).convert('RGB'))
   surfaces.append((position,uv,indices,texture,factor))
 for child in node.get('children',[]):visit(child,world)
for node in doc['scenes'][doc.get('scene',0)]['nodes']:visit(node,np.eye(4))
points=np.concatenate([part[0] for part in surfaces]);lo=points.min(axis=0);hi=points.max(axis=0);height=hi[1]-lo[1]
panes=[];width=420;screen_height=620
light=np.array([-.3,.7,1]);light/=np.linalg.norm(light)
for sign,crop in [(1,False),(-1,False),(1,True),(-1,True)]:
 pixels=np.zeros((screen_height,width,3),dtype=np.uint8);pixels[:]=[24,37,45];depth=np.full((screen_height,width),-np.inf)
 if crop:
  top=hi[1]+height*.025;bottom=lo[1]+height*.64;cx=(lo[0]+hi[0])/2;cy=(top+bottom)/2;scale=min((screen_height-60)/(top-bottom),(width-30)/(height*.48))
 else:cx=(lo[0]+hi[0])/2;cy=(lo[1]+hi[1])/2;scale=min((screen_height-65)/height,(width-30)/(hi[0]-lo[0]))
 for position,uv,indices,texture,factor in surfaces:
  projected=np.c_[width/2+(position[:,0]*sign-cx*sign)*scale,screen_height/2-(position[:,1]-cy)*scale]
  for ids in indices:
   tri=projected[ids];x0=max(0,int(np.floor(tri[:,0].min())));x1=min(width-1,int(np.ceil(tri[:,0].max())));y0=max(28,int(np.floor(tri[:,1].min())));y1=min(screen_height-20,int(np.ceil(tri[:,1].max())))
   if x0>x1 or y0>y1:continue
   (ax,ay),(bx,by),(cx0,cy0)=tri;den=(by-cy0)*(ax-cx0)+(cx0-bx)*(ay-cy0)
   if abs(den)<1e-9:continue
   yy,xx=np.mgrid[y0:y1+1,x0:x1+1];xx=xx+.5;yy=yy+.5
   wa=((by-cy0)*(xx-cx0)+(cx0-bx)*(yy-cy0))/den;wb=((cy0-ay)*(xx-cx0)+(ax-cx0)*(yy-cy0))/den;wc=1-wa-wb
   z=(wa*position[ids[0],2]+wb*position[ids[1],2]+wc*position[ids[2],2])*sign
   target=depth[y0:y1+1,x0:x1+1];mask=(wa>=-1e-7)&(wb>=-1e-7)&(wc>=-1e-7)&(z>target)
   if not mask.any():continue
   texture_uv=wa[...,None]*uv[ids[0]]+wb[...,None]*uv[ids[1]]+wc[...,None]*uv[ids[2]]
   tx=np.clip((texture_uv[...,0]%1*texture.shape[1]).astype(int),0,texture.shape[1]-1);ty=np.clip((texture_uv[...,1]%1*texture.shape[0]).astype(int),0,texture.shape[0]-1)
   normal=np.cross(position[ids[1]]-position[ids[0]],position[ids[2]]-position[ids[0]]);length=np.linalg.norm(normal)
   shade=.78+.22*abs(np.dot(normal/length,light)) if length else 1
   rgb=np.clip(texture[ty,tx]*factor*shade,0,255).astype(np.uint8);pixels[y0:y1+1,x0:x1+1][mask]=rgb[mask];target[mask]=z[mask]
 im=Image.fromarray(pixels);draw=ImageDraw.Draw(im);draw.text((12,10),('Front +Z' if sign>0 else 'Back -Z')+(' / head' if crop else ' / bind pose'),fill='white');panes.append(im)
out=Image.new('RGB',(width*4,screen_height))
for i,im in enumerate(panes):out.paste(im,(i*width,0))
out.save(a.output);print(str(a.output))
