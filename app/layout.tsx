import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'سوق DZ — منصة الخدمات والسلع الجزائرية',
  description: 'منصة جزائرية تجمع الخدمات والمشاريع والسلع في مكان واحد.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  );
}
