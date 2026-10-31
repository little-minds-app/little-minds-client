import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'Little Minds — Parent', description: 'Parent sign-in' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="tr"><body style={{ fontFamily: 'system-ui, sans-serif', maxWidth: 480, padding: 24, margin: 'auto', lineHeight: 1.5 }}>{children}</body></html>;
}
