import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'Little Minds — Parent', description: 'Little Minds parent web foundation' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="tr"><body><div className="shell">{children}</div></body></html>;
}
