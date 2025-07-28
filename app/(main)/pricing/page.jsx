
"use client";

import { CheckCircle } from 'lucide-react';
import { useState, useEffect } from 'react';
import { toast } from 'sonner';
import { updateSubscription } from '@/actions/account';
import { useUser } from '@clerk/nextjs';
import { db } from '@/lib/prisma'; // Assuming you have a client-side prisma instance or similar

const PricingPage = () => {
  const { user } = useUser();
  const [currentSubscription, setCurrentSubscription] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const fetchUserSubscription = async () => {
      if (user) {
        try {
          const response = await fetch(`/api/user-subscription`);
          const data = await response.json();
          if (data.subscription) {
            setCurrentSubscription(data.subscription);
          }
        } catch (error) {
          console.error("Failed to fetch user subscription:", error);
        }
      }
    };
    fetchUserSubscription();
  }, [user]);

  const tiers = [
    {
      name: 'Free',
      price: '$0',
      features: [
        '50 Transactions per month',
        'Basic budgeting tools',
        'Standard reporting',
        'Email support',
      ],
      cta: 'Current Plan',
      buttonClass: 'bg-gray-600 cursor-not-allowed',
      subscriptionTier: 'FREE',
    },
    {
      name: 'Pro',
      price: '$10',
      features: [
        '500 Transactions per month',
        'Advanced budgeting tools',
        'Detailed reporting and analytics',
        'Priority email support',
        'Receipt scanning',
      ],
      cta: 'Upgrade to Pro',
      buttonClass: 'bg-indigo-600 hover:bg-indigo-700',
      subscriptionTier: 'PRO',
    },
    {
      name: 'Premium',
      price: '$25',
      features: [
        'Unlimited Transactions',
        'All Pro features',
        'AI-powered financial insights',
        'Dedicated phone support',
        'Multi-user access',
      ],
      cta: 'Upgrade to Premium',
      buttonClass: 'bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-700 hover:to-indigo-700',
      subscriptionTier: 'PREMIUM',
    },
  ];

  const handleUpgrade = async (tierName) => {
    setLoading(true);
    try {
      const result = await updateSubscription(tierName);
      if (result.success) {
        toast.success(result.message);
        setCurrentSubscription(tierName); // Update local state
      } else {
        toast.error(result.error || 'Failed to update subscription.');
      }
    } catch (error) {
      console.error("Error updating subscription:", error);
      toast.error('An unexpected error occurred.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen landing-bg text-white pt-20">
      <div className="container mx-auto px-4 py-16">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold tracking-tight sm:text-6xl gradient-title">
            Pricing Plans
          </h1>
          <p className="mt-4 text-lg text-gray-300">
            Choose the plan that's right for your financial journey.
          </p>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {tiers.map((tier) => (
            <div
              key={tier.name}
              className="bg-white/5 backdrop-blur-md rounded-lg shadow-lg p-8 flex flex-col"
            >
              <h3 className="text-2xl font-semibold text-center">{tier.name}</h3>
              <p className="mt-4 text-center">
                <span className="text-5xl font-bold">{tier.price}</span>
                <span className="text-gray-400">/month</span>
              </p>
              <ul className="mt-6 space-y-4 flex-grow">
                {tier.features.map((feature) => (
                  <li key={feature} className="flex items-center">
                    <CheckCircle className="h-5 w-5 text-green-400 mr-2" />
                    <span className="text-gray-200">{feature}</span>
                  </li>
                ))}
              </ul>
              <button
                className={`mt-8 w-full py-3 rounded-lg font-semibold transition-all duration-300 ${
                  tier.buttonClass
                } ${
                  currentSubscription === tier.subscriptionTier || loading
                    ? 'opacity-50 cursor-not-allowed'
                    : ''
                }`}
                onClick={() => handleUpgrade(tier.subscriptionTier)}
                disabled={currentSubscription === tier.subscriptionTier || loading}
              >
                {currentSubscription === tier.subscriptionTier
                  ? 'Current Plan'
                  : loading && tier.subscriptionTier === currentSubscription
                  ? 'Updating...'
                  : tier.cta}
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default PricingPage;
