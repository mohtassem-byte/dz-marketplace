import { supabase } from './supabase';

export async function currentUser(){ if(!supabase) return null; const {data:{user}}=await supabase.auth.getUser(); return user; }
function ready(){ if(!supabase) throw new Error('Supabase غير مهيأ'); return supabase; }

export async function createProject(input:{title:string;description:string;category_id?:string;budget_dzd?:number;deadline_days?:number;wilaya?:string}){ const db=ready(); const user=await currentUser(); if(!user) throw new Error('يجب تسجيل الدخول'); return db.from('projects').insert({...input,client_id:user.id}).select().single(); }
export async function createService(input:{title:string;description:string;category_id?:string;price_dzd:number;delivery_days:number;wilaya?:string}){ const db=ready(); const user=await currentUser(); if(!user) throw new Error('يجب تسجيل الدخول'); return db.from('services').insert({...input,provider_id:user.id}).select().single(); }
export async function listServices(){ if(!supabase) return {data:[],error:null}; return supabase.from('services').select('id,title,description,price_dzd,delivery_days,wilaya,profiles(full_name),categories(name,slug)').eq('is_active',true).order('created_at',{ascending:false}); }
export async function listProjects(){ if(!supabase) return {data:[],error:null}; return supabase.from('projects').select('id,title,description,budget_dzd,deadline_days,wilaya,status,created_at,profiles(full_name),categories(name,slug)').eq('status','open').order('created_at',{ascending:false}); }
export async function listProducts(){ if(!supabase) return {data:[],error:null}; return supabase.from('products').select('id,title,description,price_dzd,stock,wilaya,delivery_available,profiles(full_name),categories(name,slug)').eq('is_active',true).order('created_at',{ascending:false}); }
export async function createProduct(input:{title:string;description:string;category_id?:string;price_dzd:number;stock:number;wilaya?:string;delivery_available?:boolean}){ const db=ready(); const user=await currentUser(); if(!user) throw new Error('يجب تسجيل الدخول'); return db.from('products').insert({...input,seller_id:user.id}).select().single(); }
