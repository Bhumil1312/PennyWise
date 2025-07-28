import { SignedIn, SignedOut, SignInButton, UserButton } from "@clerk/nextjs";
import Image from "next/image";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { PenBox, LayoutDashboard } from "lucide-react";
import { checkUser } from "@/lib/checkUser";

const header = async () => {
  await checkUser();

  return (
    <div className="fixed top-0 w-full bg-white/2 backdrop-blur-md z-25 border-b">
         <nav className="container mx-auto px-4 py-4 flex items-center justify-between">
        <Link href="/">
          <Image
            src={"/Pennywise.svg"}
            alt="PennyWise Logo"
            width={200}
            height={60}
            className="h-12 w-auto object-contain"
          />
        </Link>

        {/* Authentication and Transaction related Buttons */}
        <div className="flex items-center space-x-4">
          <SignedIn>
            <a href="/transactionHistory/add">
              <Button variant="ghost" className="flex items-center gap-2">
                <span className="hidden md:inline">Import From PDF</span>
              </Button>
            </a>
            <a href="/transaction/create">
              <Button variant="ghost" className="flex items-center gap-2">
                <PenBox size={18} />
                <span className="hidden md:inline">Add Transaction</span>
              </Button>
            </a>
            <Link href="/dashboard">
              <Button variant="ghost" className="flex items-center gap-2" >
                <span className="hidden md:inline">Dashboard</span>
              </Button>
            </Link>
            <Link href="/pricing">
              <Button variant="ghost" className="flex items-center gap-2" >
                <span className="hidden md:inline">Pricing</span>
              </Button>
            </Link>
          </SignedIn>
          <SignedOut>
            <SignInButton forceRedirectUrl="/dashboard">
              <Button className="cursor-pointer">Login</Button>
            </SignInButton>
          </SignedOut>
          <SignedIn>
            <UserButton
              appearance={{
                elements: {
                  avatarBox: "w-15 h-15"
                },
              }}
            />
          </SignedIn>
        </div>
      </nav>
    </div>
  )
}

export default header;
