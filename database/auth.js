/* 教育管家｜Supabase Auth + 家庭账号桥 v1
 * 浏览器仅使用 publishable key；登录后的 JWT 交给 RLS。
 */
(function(){
  'use strict';
  const KEY='educationOS_db_config';
  const esc=v=>String(v==null?'':v).replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const cfg=()=>{try{return JSON.parse(localStorage.getItem(KEY)||'{}')}catch(e){return{}}};
  const saveCfg=c=>localStorage.setItem(KEY,JSON.stringify(c));
  const base=()=>String(cfg().url||'').replace(/\/$/,'');
  async function authRequest(path,body){
    const c=cfg();
    if(!c.url||!c.publishableKey)throw new Error('请先配置数据库地址和 Publishable Key');
    const r=await fetch(base()+'/auth/v1/'+path,{method:'POST',headers:{'apikey':c.publishableKey,'Content-Type':'application/json'},body:JSON.stringify(body)});
    const data=await r.json().catch(()=>({}));
    if(!r.ok)throw new Error(data.error_description||data.msg||data.message||'登录失败');
    return data;
  }
  async function rpc(name,args,token){
    const c=cfg();
    const r=await fetch(base()+'/rest/v1/rpc/'+name,{method:'POST',headers:{'apikey':c.publishableKey,'Authorization':'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(args||{})});
    const data=await r.json().catch(()=>({}));
    if(!r.ok)throw new Error(data.message||data.hint||'数据库请求失败');
    return data;
  }
  function open(){
    let box=document.getElementById('osAuthBox');
    if(!box){
      box=document.createElement('div');box.id='osAuthBox';
      box.style='position:fixed;inset:0;background:rgba(0,0,0,.38);display:none;align-items:center;justify-content:center;padding:20px;z-index:100;';
      box.innerHTML='<div style="width:min(460px,100%);background:var(--surface);border:1px solid var(--border);border-radius:18px;padding:22px;box-shadow:0 20px 60px rgba(0,0,0,.25)">'+
        '<div style="display:flex;justify-content:space-between;align-items:center"><div><h2 style="margin:0">家庭账号</h2><div class="label" id="osAuthSub">使用家庭账号登录教育管家</div></div><button id="osAuthClose" class="link">关闭</button></div>'+
        '<div id="osAuthBody" style="margin-top:18px"></div></div>';
      document.body.appendChild(box);
      box.addEventListener('click',e=>{if(e.target===box)box.style.display='none';});
      document.getElementById('osAuthClose').onclick=()=>box.style.display='none';
    }
    box.style.display='flex';render();
  }
  async function context(token){
    const x=await rpc('education_os_auth_context',{},token);
    return x||null;
  }
  async function render(){
    const box=document.getElementById('osAuthBox'),body=document.getElementById('osAuthBody');if(!body)return;
    const c=cfg();
    if(c.accessToken){
      try{
        const x=await context(c.accessToken);
        const families=x?.families||[];
        if(families.length){
          const family=families[0];
          c.familyId=family.family_id;c.enabled=true;saveCfg(c);
          body.innerHTML='<div class="card"><b>已登录</b><div style="margin-top:8px">'+esc(x.display_name||x.email||'家庭成员')+'</div><div class="label" style="margin-top:4px">家庭：'+esc(family.family_id)+'　角色：'+esc(family.role_code)+'</div></div><div style="margin-top:14px;display:flex;gap:10px"><button class="primary" id="osAuthSync">立即同步数据库</button><button class="link" id="osAuthLogout">退出账号</button></div>';
          document.getElementById('osAuthSync').onclick=()=>window.EducationOSData?.sync().then(()=>{alert('数据库同步完成');});
          document.getElementById('osAuthLogout').onclick=logout;
        }else{
          body.innerHTML='<div class="label">账号已登录，但还没有家庭档案。</div><div style="margin-top:14px"><input id="osFamilyName" placeholder="家庭名称" style="width:100%;padding:11px;border:1px solid var(--border);border-radius:10px;background:var(--surface2);color:var(--text)"></div><div style="margin-top:12px"><input id="osDisplayName" placeholder="你的姓名" value="'+esc(x?.display_name||'')+'" style="width:100%;padding:11px;border:1px solid var(--border);border-radius:10px;background:var(--surface2);color:var(--text)"></div><button class="primary" id="osCreateFamily" style="margin-top:14px;width:100%">建立我的家庭</button>';
          document.getElementById('osCreateFamily').onclick=async()=>{
            try{const familyName=document.getElementById('osFamilyName').value.trim();const displayName=document.getElementById('osDisplayName').value.trim();if(!familyName)throw new Error('请输入家庭名称');await rpc('education_os_create_family',{p_family_name:familyName,p_display_name:displayName||null},c.accessToken);await render();window.dispatchEvent(new Event('educationOS:changed'));}catch(e){alert(e.message);}
          };
        }
      }catch(e){body.innerHTML='<div class="label">登录状态已失效，请重新登录。</div><button class="primary" id="osReLogin" style="margin-top:14px">重新登录</button>';document.getElementById('osReLogin').onclick=logout;}
      return;
    }
    body.innerHTML='<form id="osLoginForm"><label class="label">邮箱</label><input id="osEmail" type="email" required style="width:100%;padding:11px;margin:6px 0 12px;border:1px solid var(--border);border-radius:10px;background:var(--surface2);color:var(--text)"><label class="label">密码</label><input id="osPassword" type="password" required style="width:100%;padding:11px;margin:6px 0 14px;border:1px solid var(--border);border-radius:10px;background:var(--surface2);color:var(--text)"><button class="primary" type="submit" style="width:100%">登录家庭账号</button></form><div id="osLoginError" class="label" style="margin-top:10px;color:var(--red)"></div>';
    document.getElementById('osLoginForm').onsubmit=async e=>{
      e.preventDefault();const err=document.getElementById('osLoginError');err.textContent='';
      try{const data=await authRequest('token?grant_type=password',{email:document.getElementById('osEmail').value.trim(),password:document.getElementById('osPassword').value});const cc=cfg();cc.accessToken=data.access_token;cc.refreshToken=data.refresh_token||null;saveCfg(cc);await render();window.dispatchEvent(new Event('educationOS:changed'));}catch(x){err.textContent=x.message;}
    };
  }
  function logout(){const c=cfg();delete c.accessToken;delete c.refreshToken;delete c.familyId;c.enabled=false;saveCfg(c);render();}
  function init(){
    const btn=document.getElementById('osAuthButton');if(btn)btn.onclick=open;
    window.EducationOSAuth={open,logout,context};
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();