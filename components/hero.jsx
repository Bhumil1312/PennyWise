"use client";

import React, { useEffect, useRef } from "react";
import Image from "next/image";
import { Button } from "@/components/ui/button";
import Link from "next/link";

const HeroSection = () => {
  const imageRef = useRef(null);

  useEffect(() => {
    const imageElement = imageRef.current;

    const handleScroll = () => {
      const scrollPosition = window.scrollY;
      const scrollThreshold = 100;

      if (scrollPosition > scrollThreshold) {
        imageElement.classList.add("scrolled");
      } else {
        imageElement.classList.remove("scrolled");
      }
    };

    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <section className="pt-40 pb-20 px-4 hero-section landing-bg">
      <div className="container mx-auto text-center">
        <h1 className="hero-title">
          Smarter Money, Brighter Future.
        </h1>
        <p className="hero-tagline">
          Understand where your money goes - Track, Manage, and Master your finances.
        </p>
        <div className="mt-6 flex justify-center gap-4">
          <Link href="/dashboard">
            <Button className="text-base px-8 py-2 rounded-lg font-semibold animate-bounce">
              Start for Free
            </Button>
          </Link>
          <Link href="/pageUnderDev">
            <Button variant="ghost" className="text-base px-8 py-2 rounded-lg font-semibold">
              Watch Demo
            </Button>
          </Link>
        </div>
        <div className="hero-image-wrapper mt-5 md:mt-0">
          <div ref={imageRef} className="hero-image">
            <Image
              src="/PennyWise-Dashboard.png"
              width={1280}
              height={720}
              alt="Dashboard Preview"
              className="rounded-lg shadow-2xl border mx-auto"
              priority
            />
          </div>
        </div>
      </div>
    </section>
  );
};

export default HeroSection;
