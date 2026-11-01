import { NextRequest, NextResponse } from 'next/server';
import { forwardChildRequest } from '../forward';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function PATCH(request: NextRequest, context: { params: Promise<{ childId: string }> }) {
  const { childId } = await context.params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(childId)) {
    return NextResponse.json({ error: 'not_found' }, { status: 404 });
  }
  return forwardChildRequest(request, '/v1/web/children/' + childId, 'PATCH');
}
