import { NextRequest } from 'next/server';
import { forwardChildRequest } from '../../children/forward';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  return forwardChildRequest(
    request,
    '/v1/web/insights/session-kpis' + request.nextUrl.search,
    'GET',
  );
}
