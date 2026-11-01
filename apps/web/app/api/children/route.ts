import { NextRequest } from 'next/server';
import { forwardChildRequest } from './forward';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  return forwardChildRequest(request, '/v1/web/children', 'GET');
}

export async function POST(request: NextRequest) {
  return forwardChildRequest(request, '/v1/web/children', 'POST');
}
