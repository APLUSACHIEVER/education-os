# 教育管家｜数据库

这是教育管家的正式数据层基础，采用 **PostgreSQL / Supabase 兼容结构**。

## 当前原则

1. 家庭是最高数据隔离单位：所有核心业务表都有 `family_id`。
2. 学生是教育数据核心：学生 → 学年 → 学科。
3. Master 数据与家庭交易数据分开。
4. 课程、课次、课时包、费用、教师反馈互相可追溯。
5. 接送、司机、车辆、临时安排与课程共享学生和日期时间。
6. 冲突由课程、接送、临时安排等业务记录产生。
7. 教师反馈可以进入学业记录，也可以生成待处理任务。
8. 学生时间线不单独重复存储，而是由业务记录汇总产生。
9. 家庭报告同样从统一业务数据实时计算。
10. 暂时不把真实家庭数据写入 GitHub。

## 文件

- `schema.sql`：正式数据库表、关系、索引。
- `seed.sql`：Master 学科基础数据。
- 后续：把现有浏览器 `localStorage` 数据适配到这些表，再接 Supabase/PostgreSQL。

## Secondary

Secondary 保留：
- IP
- Mainstream / SBB
- G1 / G2 / G3（历史/过渡路径兼容）
- PG1 / PG2 / PG3

并保留 Additional Mathematics、Humanities、Art、D&T、Food & Consumer Education、Computing、Elective / Combined Subject 等字段。

POLY 与 MI 不纳入教育管家主数据模型。

## 数据迁移原则

现有前端：
`educationOS_students`
`educationOS_relations`
`educationOS.familyProfile`

未来迁移到数据库时，不改变前端业务逻辑，只增加一个数据访问层：
**页面 → 数据访问层 → PostgreSQL/Supabase**

这样以后可以把本地数据、云端数据库、登录权限逐步切换，而不需要重写整个教育管家。
