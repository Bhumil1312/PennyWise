import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function PageUnderDevelopment() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[50vh] px-4 text-center">
      <h1 className="text-6xl font-bold gradient-title mb-4">🚧</h1>
      <h2 className="text-2xl font-semibold mb-4">Page Under Development</h2>
      <p className="text-gray-600 mb-8 max-w-xl">
        This page is currently under construction. I am working hard to bring you something great very soon. Stay tuned!
      </p>
      <Link href="/">
        <Button>Return Home</Button>
      </Link>
    </div>
  );
}
