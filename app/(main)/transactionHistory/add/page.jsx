import { getAccounts } from '@/actions/account';
import { BulkTransactionForm } from '../_components/bulk-transaction-form';

export default async function BulkTransactionPage() {
  const accounts = await getAccounts();
  return <BulkTransactionForm accounts={accounts} />;
}
