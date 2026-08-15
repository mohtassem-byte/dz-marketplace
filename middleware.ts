import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest){
 const protectedPath=request.nextUrl.pathname.startsWith('/dashboard');
 if(protectedPath && !request.cookies.getAll().some(c=>c.name.includes('auth-token'))){
   const url=request.nextUrl.clone(); url.pathname='/auth'; url.searchParams.set('next',request.nextUrl.pathname); return NextResponse.redirect(url);
 }
 return NextResponse.next();
}
export const config={matcher:['/dashboard/:path*']};
