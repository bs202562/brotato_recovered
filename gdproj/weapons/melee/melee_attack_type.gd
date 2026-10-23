class_name MeleeAttackType

# 资源和存档保存的是整数，显式固定数值，避免调整顺序改变攻击行为。
enum AttackType { THRUST = 0, SWEEP = 1 }

# 保留现有战斗代码使用的访问方式，数值统一来自上面的枚举。
const THRUST = AttackType.THRUST
const SWEEP = AttackType.SWEEP
