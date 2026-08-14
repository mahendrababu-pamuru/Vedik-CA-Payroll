async function requirePayrollSession(){if(!window.sb)return null;const {data:{session}}=await sb.auth.getSession();if(!session){location.href='index.html';return null}
 const {data:isAdmin,error:adminError}=await sb.rpc('is_platform_admin');
 if(!adminError&&isAdmin===true){const selectedTenant=sessionStorage.getItem('platform_tenant_id');let tenantId=null,tenantName='Platform Administration';if(selectedTenant){const {data:tenant}=await sb.from('tenants').select('name,status').eq('id',selectedTenant).maybeSingle();if(tenant?.status==='active'){tenantId=selectedTenant;tenantName=tenant.name}else sessionStorage.removeItem('platform_tenant_id')}window.payrollSession={session,tenantId,role:'platform_admin',tenantName};return window.payrollSession}
 const {data:member,error:memberError}=await sb.from('tenant_members').select('tenant_id,role,status,tenants(name,status)').eq('user_id',session.user.id).eq('status','active').limit(1).maybeSingle();
 if(memberError){console.error('Membership check failed:',memberError);document.body.innerHTML='<main class="blocked"><h2>Unable to verify account</h2><p>Please contact the payroll administrator.</p></main>';return null}
 if(!member){await sb.auth.signOut();location.href='index.html?error=no_membership';return null}
 if(member.tenants?.status!=='active'){document.body.innerHTML='<main class="blocked"><h2>Subscription inactive</h2><p>Please contact the payroll administrator.</p></main>';return null}
 window.payrollSession={session,tenantId:member.tenant_id,role:member.role,tenantName:member.tenants?.name};return window.payrollSession}
async function payrollLogout(){await sb.auth.signOut();location.href='index.html'}
