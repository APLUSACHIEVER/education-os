/* 教育管家｜数据库数据访问层 v1
 * 目标：localStorage → PostgreSQL/Supabase 的渐进式迁移。
 * 未配置数据库时完全保持现有前端行为；配置后先同步家庭/学生/核心交易数据。
 */
(function(){
  'use strict';
  const KEY='educationOS_db_config';
  const DEVICE='educationOS_device_key';
  const REL='educationOS_relations';
  const STU='educationOS_students';
  const CACHE='educationOS_db_cache_v1';

  const safe=(fn,fallback)=>{try{return fn()}catch(e){console.warn('EducationOS DB:',e);return fallback;}};
  const cfg=()=>safe(()=>JSON.parse(localStorage.getItem(KEY)||'{}'),{});
  const cache=()=>safe(()=>JSON.parse(localStorage.getItem(CACHE)||'{}'),{});
  const writeCache=x=>localStorage.setItem(CACHE,JSON.stringify(x));
  const enabled=()=>{const c=cfg();return !!(c.enabled&&c.url&&c.publishableKey&&c.familyId);};

  function headers(){
    const c=cfg();
    return {'apikey':c.publishableKey,'Authorization':'Bearer '+(c.accessToken||c.publishableKey),'Content-Type':'application/json','Prefer':'return=representation'};
  }
  async function rest(path,options={}){
    const c=cfg();
    if(!enabled()) throw new Error('数据库未配置');
    const res=await fetch(c.url.replace(/\/$/,'')+'/rest/v1/'+path,{...options,headers:{...headers(),...(options.headers||{})}});
    if(!res.ok) throw new Error('数据库请求失败 '+res.status+' '+await res.text());
    return res.status===204?null:res.json();
  }

  async function pullCore(){
    if(!enabled()) return false;
    const c=cfg(), next=cache();
    const tables=['students','teachers','courses','packages','lessons','teacher_feedback','drivers','vehicles','transport_tasks','temporary_arrangements','conflicts','tasks','academic_goals','assessments','progress_records','payments','activities','calendar_events','dsa_plans','dsa_activities'];
    for(const table of tables){
      try{
        const rows=await rest(table+'?family_id=eq.'+encodeURIComponent(c.familyId)+'&select=*');
        next[table]=rows||[];
      }catch(e){console.warn('同步失败:',table,e);}
    }
    await pullAcademic(next);
    writeCache(next);
    if(next.students) localStorage.setItem(STU,JSON.stringify(next.students.map(mapStudentRemoteToLocal)));
    if(next.courses||next.lessons||next.tasks||next.payments) localStorage.setItem(REL,JSON.stringify(buildRelations(next)));
    window.dispatchEvent(new Event('educationOS:changed'));
    return true;
  }

  async function pullAcademic(next){
    const c=cfg();
    if(!Array.isArray(next.students)||!next.students.length)return;
    const ids=next.students.map(x=>x.id).filter(Boolean);
    try{
      const years=await rest('academic_years?student_id=in.('+ids.map(encodeURIComponent).join(',')+')&select=*');
      next.academic_years=years||[];
    }catch(e){console.warn('同步失败: academic_years',e);next.academic_years=[];}
    try{
      const yearIds=(next.academic_years||[]).map(x=>x.id).filter(Boolean);
      next.student_subjects=yearIds.length?await rest('student_subjects?academic_year_id=in.('+yearIds.map(encodeURIComponent).join(',')+')&select=*'):[];
    }catch(e){console.warn('同步失败: student_subjects',e);next.student_subjects=[];}
    try{
      const schoolYears=(next.academic_years||[]).map(x=>x.id).filter(Boolean);
      next.student_school_history=schoolYears.length?await rest('student_school_history?academic_year_id=in.('+schoolYears.map(encodeURIComponent).join(',')+')&select=*'):[];
    }catch(e){console.warn('同步失败: student_school_history',e);next.student_school_history=[];}
    const byStudent={};
    (next.academic_years||[]).forEach(y=>{
      const key=String(y.student_id);(byStudent[key] ||= []).push({
        id:y.id,year:y.year_label,grade:y.grade_code,school:y.school_name||'',path:y.pathway||'',stage:y.education_level==='secondary'?'Secondary':y.education_level==='jc'?'JC':'Primary',className:y.class_name||'',notes:y.notes||'',updatedAt:y.updated_at,
        subjectRecords:{}
      });
    });
    (next.student_subjects||[]).forEach(x=>{
      const ys=(next.academic_years||[]).find(y=>String(y.id)===String(x.academic_year_id));
      if(!ys)return; const rec=(byStudent[String(ys.student_id)]||[]).find(y=>String(y.id)===String(ys.id));
      if(rec)rec.subjectRecords[x.subject_name_snapshot||x.subject_id]={teacher:x.teacher_name||'',frequency:x.weekly_frequency||'',mode:x.teaching_mode||'',courseId:x.tuition_course_id||'',subjectId:x.subject_id,updatedAt:x.updated_at};
    });
    next.students=next.students.map(s=>({...s,academicYears:byStudent[String(s.id)]||[]}));
  }

  function mapStudentRemoteToLocal(s){
    return {
      ...s,
      id:s.id,
      familyId:s.family_id,
      preferredName:s.preferred_name,
      dateOfBirth:s.date_of_birth,
      createdAt:s.created_at,
      updatedAt:s.updated_at
    };
  }

  function buildRelations(c){
    const r=safe(()=>JSON.parse(localStorage.getItem(REL)||'{}'),{});
    const map={
      teachers:'teachers',courses:'courses',packages:'packages',lessons:'lessons',
      feedbacks:'teacher_feedback',drivers:'drivers',vehicles:'vehicles',
      transportTasks:'transport_tasks',temporaryArrangements:'temporary_arrangements',
      conflicts:'conflicts',tasks:'tasks',academicGoals:'academic_goals',
      assessments:'assessments',progressRecords:'progress_records',payments:'payments',
      activities:'activities',calendarEvents:'calendar_events',
      dsaPlans:'dsa_plans',dsaActivities:'dsa_activities'
    };
    Object.keys(map).forEach(k=>{if(Array.isArray(c[map[k]]))r[k]=c[map[k]].map(mapRemoteRow);});
    return r;
  }

  function mapRemoteRow(x){
    const o={...x};
    Object.keys(o).forEach(k=>{
      const camel=k.replace(/_([a-z])/g,(_,c)=>c.toUpperCase());
      if(camel!==k){o[camel]=o[k];delete o[k];}
    });
    return o;
  }

  function mapLocalRow(x){
    const o={};
    Object.keys(x||{}).forEach(k=>{
      const snake=k.replace(/[A-Z]/g,m=>'_'+m.toLowerCase());
      o[snake]=x[k];
    });
    return o;
  }

  async function upsert(table,row){
    if(!enabled()) return {localOnly:true,row};
    const c=cfg();
    const remote=mapLocalRow(row);
    remote.family_id=remote.family_id||c.familyId;
    const id=remote.id;
    const path=table+(id?'?id=eq.'+encodeURIComponent(id):'');
    return rest(path,{method:'POST',headers:{'Prefer':'resolution=merge-duplicates,return=representation'},body:JSON.stringify(remote)});
  }

  async function remove(table,id){
    if(!enabled()) return;
    return rest(table+'?id=eq.'+encodeURIComponent(id),{method:'DELETE'});
  }


  async function testConnection(){
    if(!enabled()) return {ok:false,reason:'未配置数据库'};
    try{
      await rest('families?id=eq.'+encodeURIComponent(cfg().familyId)+'&select=id&limit=1');
      return {ok:true,familyId:cfg().familyId};
    }catch(e){return {ok:false,reason:e.message||String(e)};}
  }

  async function upsertStudent(row){
    const x={...row}; delete x.academicYears;
    return upsert('students',x);
  }
  async function upsertAcademicYear(row){
    const x={...row};
    x.year_label=x.year_label||x.year; x.start_date=x.start_date||x.startDate||new Date().getFullYear()+'-01-01'; x.end_date=x.end_date||x.endDate||new Date().getFullYear()+'-12-31';
    x.education_level=x.education_level||((x.stage||'Primary')==='Secondary'?'secondary':(x.stage||'Primary')==='JC'?'jc':'primary');
    x.grade_code=x.grade_code||x.grade||'P1'; delete x.year; delete x.startDate; delete x.endDate; delete x.stage; delete x.grade;
    const id=x.id; return rest('academic_years'+(id?'?id=eq.'+encodeURIComponent(id):''),{method:'POST',headers:{'Prefer':'resolution=merge-duplicates,return=representation'},body:JSON.stringify(x)});
  }
  async function upsertStudentSubject(row){
    const x={...row}; const id=x.id;
    return rest('student_subjects'+(id?'?id=eq.'+encodeURIComponent(id):''),{method:'POST',headers:{'Prefer':'resolution=merge-duplicates,return=representation'},body:JSON.stringify(x)});
  }

  const TABLE_FIELDS={
    students:['id','family_id','name','preferred_name','date_of_birth','gender','nationality','status','notes','created_at','updated_at'],
    teachers:['id','family_id','name','phone','email','subjects','teaching_mode','status','notes','created_at','updated_at'],
    courses:['id','family_id','student_id','academic_year_id','subject_id','teacher_id','name','course_type','mode','weekly_schedule','start_date','end_date','duration_hours','status','notes','created_at','updated_at'],
    packages:['id','family_id','student_id','course_id','name','total_hours','used_hours','total_amount','start_date','expiry_date','status','notes','created_at','updated_at'],
    lessons:['id','family_id','course_id','package_id','student_id','teacher_id','subject_id','lesson_date','start_time','duration_hours','status','planned','note','completed_at','cancelled_at','updated_at','created_at'],
    teacher_feedback:['id','family_id','course_id','lesson_id','student_id','teacher_id','feedback_date','status','content','created_at','updated_at'],
    drivers:['id','family_id','name','phone','license_info','status','notes','created_at','updated_at'],
    vehicles:['id','family_id','name','registration_no','vehicle_type','capacity','status','notes','created_at','updated_at'],
    transport_tasks:['id','family_id','student_id','driver_id','vehicle_id','related_lesson_id','task_date','pickup_time','pickup_location','dropoff_location','direction','status','temporary','notes','created_at','updated_at'],
    temporary_arrangements:['id','family_id','student_id','arrangement_date','start_time','end_time','type','description','driver_id','vehicle_id','status','created_at','updated_at'],
    conflicts:['id','family_id','student_id','conflict_type','severity','conflict_date','start_time','end_time','description','source_type','source_id','is_auto_detected','status','resolved_at','resolution_note','created_at','updated_at'],
    tasks:['id','family_id','student_id','course_id','feedback_id','name','due_date','status','priority','source','note','completed_at','created_at','updated_at'],
    academic_goals:['id','family_id','student_id','academic_year_id','subject_id','title','target','due_date','status','note','created_at','updated_at'],
    assessments:['id','family_id','student_id','academic_year_id','subject_id','assessment_date','assessment_type','assessment_name','score','grade','level','note','created_at'],
    progress_records:['id','family_id','student_id','academic_year_id','subject_id','course_id','feedback_id','record_date','level','note','source','created_at'],
    payments:['id','family_id','student_id','academic_year_id','course_id','lesson_id','category','description','amount','payment_date','status','notes','created_at','updated_at'],
    activities:['id','family_id','student_id','name','activity_type','activity_date','start_time','end_time','location','status','notes','created_at','updated_at'],
    calendar_events:['id','family_id','student_id','title','event_date','start_time','end_time','event_type','location','status','notes','created_at','updated_at'],
    dsa_plans:['id','family_id','student_id','academic_year_id','school_id','title','target','status','notes','created_at','updated_at'],
    dsa_activities:['id','family_id','dsa_plan_id','activity_date','title','type','status','notes','created_at','updated_at']
  };
  const ALIAS={
    students:{preferredName:'preferred_name',dateOfBirth:'date_of_birth',createdAt:'created_at',updatedAt:'updated_at'},
    courses:{courseType:'course_type',weeklySchedule:'weekly_schedule',startDate:'start_date',endDate:'end_date',duration:'duration_hours',durationHours:'duration_hours',createdAt:'created_at',updatedAt:'updated_at'},
    packages:{totalHours:'total_hours',usedHours:'used_hours',totalAmount:'total_amount',startDate:'start_date',expiryDate:'expiry_date',createdAt:'created_at',updatedAt:'updated_at'},
    lessons:{courseId:'course_id',packageId:'package_id',studentId:'student_id',teacherId:'teacher_id',subjectId:'subject_id',date:'lesson_date',time:'start_time',duration:'duration_hours',durationHours:'duration_hours',completedAt:'completed_at',cancelledAt:'cancelled_at',createdAt:'created_at',updatedAt:'updated_at'},
    teacher_feedback:{courseId:'course_id',lessonId:'lesson_id',studentId:'student_id',teacherId:'teacher_id',date:'feedback_date',createdAt:'created_at',updatedAt:'updated_at'},
    transport_tasks:{studentId:'student_id',driverId:'driver_id',vehicleId:'vehicle_id',relatedLessonId:'related_lesson_id',date:'task_date',time:'pickup_time',from:'pickup_location',to:'dropoff_location',createdAt:'created_at',updatedAt:'updated_at'},
    temporary_arrangements:{studentId:'student_id',driverId:'driver_id',vehicleId:'vehicle_id',date:'arrangement_date',startTime:'start_time',endTime:'end_time',createdAt:'created_at',updatedAt:'updated_at'},
    conflicts:{studentId:'student_id',type:'conflict_type',title:'description',date:'conflict_date',time:'start_time',source:'source_type',sourceId:'source_id',isAutoDetected:'is_auto_detected',resolvedAt:'resolved_at',resolutionNote:'resolution_note',createdAt:'created_at',updatedAt:'updated_at'},
    tasks:{studentId:'student_id',courseId:'course_id',feedbackId:'feedback_id',title:'name',dueDate:'due_date',completedAt:'completed_at',createdAt:'created_at',updatedAt:'updated_at'},
    academic_goals:{studentId:'student_id',academicYearId:'academic_year_id',subjectId:'subject_id',goal:'title',dueDate:'due_date',createdAt:'created_at',updatedAt:'updated_at'},
    assessments:{studentId:'student_id',academicYearId:'academic_year_id',subjectId:'subject_id',date:'assessment_date',type:'assessment_type',name:'assessment_name',createdAt:'created_at'},
    progress_records:{studentId:'student_id',academicYearId:'academic_year_id',subjectId:'subject_id',courseId:'course_id',feedbackId:'feedback_id',date:'record_date',createdAt:'created_at'},
    payments:{studentId:'student_id',academicYearId:'academic_year_id',courseId:'course_id',lessonId:'lesson_id',date:'payment_date',createdAt:'created_at',updatedAt:'updated_at'},
    activities:{studentId:'student_id',activityType:'activity_type',date:'activity_date',startTime:'start_time',endTime:'end_time',createdAt:'created_at',updatedAt:'updated_at'},
    calendar_events:{studentId:'student_id',eventDate:'event_date',startTime:'start_time',endTime:'end_time',eventType:'event_type',createdAt:'created_at',updatedAt:'updated_at'},
    dsa_plans:{studentId:'student_id',academicYearId:'academic_year_id',schoolId:'school_id',createdAt:'created_at',updatedAt:'updated_at'},
    dsa_activities:{dsaPlanId:'dsa_plan_id',activityDate:'activity_date',createdAt:'created_at',updatedAt:'updated_at'}
  };
  function mapForTable(table,row){
    const fields=TABLE_FIELDS[table]; if(!fields)return null;
    const aliases=ALIAS[table]||{}, out={};
    Object.keys(row||{}).forEach(k=>{const dest=aliases[k]||k;if(fields.includes(dest)&&row[k]!==undefined)out[dest]=row[k];});
    return out;
  }
  async function pushLocalTable(table,rows){
    if(!Array.isArray(rows)||!rows.length)return;
    for(const row of rows){
      const remote=mapForTable(table,row); if(!remote)continue;
      remote.family_id=remote.family_id||cfg().familyId;
      try{await upsert(table,remote);}catch(e){console.warn('上传失败:',table,row.id||'(new)',e);}
    }
  }
  async function pushAcademicYears(ss){
    for(const s of ss||[])for(const y of (s.academicYears||[])){
      if(!y.id)continue;
      const remote={id:y.id,student_id:s.id,year_label:y.year||y.yearLabel,start_date:y.startDate||new Date().getFullYear()+'-01-01',end_date:y.endDate||new Date().getFullYear()+'-12-31',education_level:y.stage==='Secondary'?'secondary':y.stage==='JC'?'jc':'primary',grade_code:y.grade||'P1',pathway:y.path||null,school_name:y.school||null,class_name:y.className||null,notes:y.notes||null};
      try{await upsert('academic_years',remote);}catch(e){console.warn('上传失败: academic_years',y.id,e);}
      for(const name of Object.keys(y.subjectRecords||{})){
        const x=y.subjectRecords[name]||{}; if(!x.subjectId)continue;
        try{await upsert('student_subjects',{id:x.id||undefined,academic_year_id:y.id,subject_id:x.subjectId,subject_name_snapshot:name,teacher_name:x.teacher||'',weekly_frequency:x.frequency||'',teaching_mode:x.mode||'',tuition_course_id:x.courseId||null});}catch(e){console.warn('上传失败: student_subjects',name,e);}
      }
    }
  }
  async function pushLocal(){
    if(!enabled())return false;
    const r=safe(()=>JSON.parse(localStorage.getItem(REL)||'{}'),{}), ss=safe(()=>JSON.parse(localStorage.getItem(STU)||'[]'),[]);
    await pushLocalTable('students',ss); await pushAcademicYears(ss);
    const order=['teachers','drivers','vehicles','courses','packages','lessons','teacher_feedback','transport_tasks','temporary_arrangements','conflicts','tasks','academic_goals','assessments','progress_records','payments','activities','calendar_events','dsa_plans','dsa_activities'];
    for(const table of order)await pushLocalTable(table,r[table]||[]);
    return true;
  }

  function deviceKey(){
    let x=localStorage.getItem(DEVICE);
    if(!x){
      x=(crypto.randomUUID?crypto.randomUUID():('device_'+Date.now()+'_'+Math.random().toString(36).slice(2)));
      localStorage.setItem(DEVICE,x);
    }
    return x;
  }

  async function backupLocalSnapshot(){
    if(!enabled()) return false;
    const c=cfg();
    const data={
      students:safe(()=>JSON.parse(localStorage.getItem(STU)||'[]'),[]),
      relations:safe(()=>JSON.parse(localStorage.getItem(REL)||'{}'),{}),
      capturedAt:new Date().toISOString()
    };
    try{
      await rest('legacy_data_snapshots',{method:'POST',body:JSON.stringify({
        family_id:c.familyId,device_key:deviceKey(),snapshot_version:Date.now(),data
      })});
      return true;
    }catch(e){console.warn('本地快照上传失败',e);return false;}
  }

  function setConfig(next){
    const c={...cfg(),...next};
    localStorage.setItem(KEY,JSON.stringify(c));
    return {enabled:!!c.enabled,url:c.url||'',familyId:c.familyId||''};
  }

  function status(){const c=cfg();return {enabled:enabled(),configured:!!(c.url&&c.publishableKey&&c.familyId),familyId:c.familyId||'',lastSync:c.lastSync||null};}

  let syncing=false;

  window.EducationOSData={
    version:'1.1.0',
    status,
    testConnection,
    configure:setConfig,
    snapshot:backupLocalSnapshot,
    sync:async()=>{if(syncing)return false;syncing=true;try{await backupLocalSnapshot();await pushLocal();const ok=await pullCore();const c=cfg();c.lastSync=ok?new Date().toISOString():c.lastSync;localStorage.setItem(KEY,JSON.stringify(c));return ok;}finally{syncing=false;}},
    upsert,
    upsertStudent,
    upsertAcademicYear,
    upsertStudentSubject,
    remove,
    getCache:cache
  };

  window.addEventListener('online',()=>{if(enabled())window.EducationOSData.sync().catch(()=>{});});
  let timer=null;
  window.addEventListener('educationOS:changed',()=>{if(!enabled()||syncing)return;clearTimeout(timer);timer=setTimeout(()=>window.EducationOSData.sync().catch(()=>{}),1500);});
  setTimeout(()=>{if(enabled())window.EducationOSData.sync().catch(()=>{});},1200);
})();
