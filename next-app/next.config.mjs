/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  distDir: '../public',
  images: {
    unoptimized: true,
  },
};

export default nextConfig;