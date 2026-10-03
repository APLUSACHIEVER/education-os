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
    return upsert('academic_years',x);
  }
  async function upsertStudentSubject(row){return upsert('student_subjects',row);}

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

  window.EducationOSData={
    version:'1.0.0',
    status,
    testConnection,
    configure:setConfig,
    snapshot:backupLocalSnapshot,
    sync:async()=>{await backupLocalSnapshot();const ok=await pullCore();const c=cfg();c.lastSync=ok?new Date().toISOString():c.lastSync;localStorage.setItem(KEY,JSON.stringify(c));return ok;},
    upsert,
    upsertStudent,
    upsertAcademicYear,
    upsertStudentSubject,
    remove,
    getCache:cache
  };

  window.addEventListener('online',()=>{if(enabled())window.EducationOSData.sync().catch(()=>{});});
  let timer=null;
  window.addEventListener('educationOS:changed',()=>{if(!enabled())return;clearTimeout(timer);timer=setTimeout(()=>window.EducationOSData.sync().catch(()=>{}),1500);});
  setTimeout(()=>{if(enabled())window.EducationOSData.sync().catch(()=>{});},1200);
})();
