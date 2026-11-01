import { NextRequest } from 'next/server';
import { childrenProxy } from './_server';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export async function GET(request: NextRequest) { return childrenProxy(request, 'GET'); }
export async function POST(request: NextRequest) { return childrenProxy(request, 'POST'); }
