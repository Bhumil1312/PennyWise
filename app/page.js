import React from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import Image from "next/image";
import HeroSection from "@/components/hero";
import Link from "next/link";
import {
  featuresData,
  howItWorksData,
  statsData,
  testimonialsData,
} from "@/data/landing";

const LandingPage = () => {
  return (
    <div className="min-h-screen landing-bg">
      {/* Hero Section */}
      <HeroSection />

      {/* Features Section */}
      <section id="features" className="py-20">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-center mb-12">
            All-in-One Money Management
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 ">
            {featuresData.map((feature, index) => (
              <Card className="p-6 backdrop-blur-md bg-white/20 border border-gray/20 shadow-lg text-white-600" key={index}>
                <CardContent className="space-y-4 pt-4">
                  {feature.icon}
                  <h3 className="text-xl font-semibold">{feature.title}</h3>
                  <p className="text-white/50">{feature.description}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      <section className="py-10 bg-gray/2">
        <div className="container mx-auto px-4">
          <h2 className="text-3xl font-bold text-center mb-16">How PennyWise Works</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
            {howItWorksData.map((step, index) => (
              <div key={index} className="text-center">
                <div className="w-16 h-16 flex items-center justify-center mx-auto mb-6">
                  {step.icon}
                </div>
                <h3 className="text-xl font-semibold mb-4">{step.title}</h3>
                <p className="text-gray-600">{step.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="py-10 bg-gray/2">
        <div className="container mx-auto px-4 text-center">
          <h2 className="text-3xl font-bold text-white mb-4">
            Take Charge of Your Financial Future
          </h2>
          <p className="text-gray-100 mb-8 max-w-2xl mx-auto">
            Achieve confidence and clarity - start managing your money smarter with PennyWise.<br />Experience effortless tracking and powerful insights in one platform.<br />Join a thriving community committed to better budgeting and smarter spending.
          </p>
          <Link href="/dashboard">
            <Button variant="secondary" className="animate-bounce backdrop-blur-md bg-gray/15 border border-white/30 shadow-lg text-white hover:text-black">
              Start Free Trial
            </Button>
          </Link>
        </div>
      </section>
    </div>
  );
};

export default LandingPage;