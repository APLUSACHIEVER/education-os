-- 教育管家｜第一版 Master Seed
-- 不包含真实家庭、学生或财务数据

insert into subject_master
(education_level,subject_code,subject_name,subject_group,curriculum_pathway,level_code,sort_order)
values
('primary','P-ENG','English','语言','Primary','P1-P6',10),
('primary','P-MT','Mother Tongue','语言','Primary','P1-P6',20),
('primary','P-MATH','Mathematics','数学','Primary','P1-P6',30),
('primary','P-SCI','Science','科学','Primary','P3-P6',40),
('primary','P-ART','Art','艺术','Primary','P1-P6',50),
('primary','P-MUSIC','Music','艺术','Primary','P1-P6',60),
('primary','P-PE','Physical Education','体育','Primary','P1-P6',70),
('primary','P-CCE','Character and Citizenship Education','品格与公民教育','Primary','P1-P6',80),
('secondary','SEC-ENG','English','语言','Secondary','S1-S4',10),
('secondary','SEC-MT','Mother Tongue','语言','Secondary','S1-S4',20),
('secondary','SEC-MATH','Mathematics','数学','Secondary','S1-S4',30),
('secondary','SEC-AMATH','Additional Mathematics','数学','Secondary','S1-S4',35),
('secondary','SEC-SCI','Science','科学','Secondary','S1-S4',40),
('secondary','SEC-HUM','Humanities','人文','Secondary','S1-S4',50),
('secondary','SEC-ART','Art','艺术','Secondary','S1-S4',60),
('secondary','SEC-DNT','Design & Technology','设计与工艺','Secondary','S1-S4',70),
('secondary','SEC-FCE','Food & Consumer Education','食品与消费者教育','Secondary','S1-S4',80),
('secondary','SEC-COMPUTING','Computing','计算机','Secondary','S1-S4',90),
('secondary','SEC-ELECTIVE','Elective / Combined Subject','选修 / 组合科目','Secondary','S3-S4',100),
('jc','JC-GP','General Paper','核心','JC','H1/H2',10),
('jc','JC-PW','Project Work','核心','JC','H1/H2',20),
('jc','JC-MT','Mother Tongue','语言','JC','H1',30),
('jc','JC-CLL','Chinese Language & Literature','语言与文学','JC','H1/H2',40),
('jc','JC-MLL','Malay Language & Literature','语言与文学','JC','H1/H2',50),
('jc','JC-TLL','Tamil Language & Literature','语言与文学','JC','H1/H2',60),
('jc','JC-ELL','English Language & Linguistics','语言','JC','H1/H2',70),
('jc','JC-MATH','Mathematics','数学','JC','H1/H2',80),
('jc','JC-FMATH','Further Mathematics','数学','JC','H2',90),
('jc','JC-BIO','Biology','科学','JC','H1/H2',100),
('jc','JC-CHEM','Chemistry','科学','JC','H1/H2',110),
('jc','JC-PHYS','Physics','科学','JC','H1/H2',120),
('jc','JC-COMP','Computing','计算机','JC','H1/H2',130),
('jc','JC-ECON','Economics','人文商科','JC','H1/H2',140),
('jc','JC-GEO','Geography','人文','JC','H1/H2',150),
('jc','JC-HIST','History','人文','JC','H1/H2',160),
('jc','JC-LIT','Literature in English','文学','JC','H1/H2',170),
('jc','JC-CHINA','China Studies','人文','JC','H1/H2',180),
('jc','JC-ART','Art','艺术','JC','H1/H2',190),
('jc','JC-MUSIC','Music','艺术','JC','H1/H2',200),
('jc','JC-TSD','Theatre Studies & Drama','艺术','JC','H1/H2',210),
('jc','JC-POA','Principles of Accounting','商科','JC','H1/H2',220),
('jc','JC-MOB','Management of Business','商科','JC','H1/H2',230)
on conflict (education_level,subject_code) do update set
subject_name=excluded.subject_name,
subject_group=excluded.subject_group,
curriculum_pathway=excluded.curriculum_pathway,
level_code=excluded.level_code,
sort_order=excluded.sort_order,
is_active=true;


-- ============================================================
-- Education OS 第一版 Master：教育路径 / 年级 / Secondary 分流
-- POLY / MI 不纳入本平台路径
-- ============================================================

insert into education_pathways(education_level,pathway_code,pathway_name,grade_start,grade_end,description,sort_order) values
('primary','PRIMARY','小学','P1','P6','新加坡小学阶段',10),
('secondary','SBB','Secondary Full SBB / G1-G3','S1','S4','按学科能力采用 G1/G2/G3',20),
('secondary','IP','Integrated Programme','S1','S4','Integrated Programme 学校路径',30),
('secondary','PG3','Mainstream PG3','S1','S4','Mainstream Post-Secondary Grade 3',40),
('secondary','PG2','Mainstream PG2','S1','S4','Mainstream Post-Secondary Grade 2',50),
('secondary','PG1','Mainstream PG1','S1','S4','Mainstream Post-Secondary Grade 1',60),
('jc','JC','Junior College','JC1','JC2','初级学院阶段',70)
on conflict(education_level,pathway_code) do update set
pathway_name=excluded.pathway_name,grade_start=excluded.grade_start,grade_end=excluded.grade_end,
description=excluded.description,sort_order=excluded.sort_order,is_active=true;

insert into grade_master(education_level,grade_code,grade_name,pathway_code,sort_order) values
('primary','P1','小学一年级','PRIMARY',10),
('primary','P2','小学二年级','PRIMARY',20),
('primary','P3','小学三年级','PRIMARY',30),
('primary','P4','小学四年级','PRIMARY',40),
('primary','P5','小学五年级','PRIMARY',50),
('primary','P6','小学六年级','PRIMARY',60),

('secondary','S1','中学一年级','SBB',10),
('secondary','S2','中学二年级','SBB',20),
('secondary','S3','中学三年级','SBB',30),
('secondary','S4','中学四年级','SBB',40),
('secondary','S1-IP','中学一年级 IP','IP',50),
('secondary','S2-IP','中学二年级 IP','IP',60),
('secondary','S3-IP','中学三年级 IP','IP',70),
('secondary','S4-IP','中学四年级 IP','IP',80),
('secondary','S1-PG3','中学一年级 PG3','PG3',90),
('secondary','S2-PG3','中学二年级 PG3','PG3',100),
('secondary','S3-PG3','中学三年级 PG3','PG3',110),
('secondary','S4-PG3','中学四年级 PG3','PG3',120),
('secondary','S1-PG2','中学一年级 PG2','PG2',130),
('secondary','S2-PG2','中学二年级 PG2','PG2',140),
('secondary','S3-PG2','中学三年级 PG2','PG2',150),
('secondary','S4-PG2','中学四年级 PG2','PG2',160),
('secondary','S1-PG1','中学一年级 PG1','PG1',170),
('secondary','S2-PG1','中学二年级 PG1','PG1',180),
('secondary','S3-PG1','中学三年级 PG1','PG1',190),
('secondary','S4-PG1','中学四年级 PG1','PG1',200),

('jc','JC1','初级学院一年级','JC',10),
('jc','JC2','初级学院二年级','JC',20)
on conflict(education_level,grade_code,pathway_code) do update set
grade_name=excluded.grade_name,sort_order=excluded.sort_order,is_active=true;

-- Secondary Full SBB / G1-G3 是学科层级能力框架，不另造学生学年。
-- 学生具体科目仍由 student_subjects 绑定 subject_master + level_code。
