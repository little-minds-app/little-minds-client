import { NextRequest } from 'next/server';
import { childrenProxy } from '../_server';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export async function PATCH(request: NextRequest, context: { params: Promise<{ childId: string }> }) {
  const { childId } = await context.params;
  return childrenProxy(request, 'PATCH', childId);
}
