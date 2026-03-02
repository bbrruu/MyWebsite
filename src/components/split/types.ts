export interface Member {
  id: string;
  name: string;
  color: string;
}

export interface ExpenseSplit {
  memberId: string;
  amount: number;
}

export interface Expense {
  id: string;
  description: string;
  paidBy: string;
  totalAmount: number;
  splits: ExpenseSplit[];
}

export interface Transaction {
  from: string;
  to: string;
  amount: number;
}

export type Step = 'members' | 'expenses' | 'settlement';

export const MEMBER_COLORS = [
  '#c0773c', // warm amber
  '#5a8a5f', // sage green
  '#6b7ab5', // slate blue
  '#a85a5a', // muted red
  '#7a6baa', // soft purple
  '#4a9090', // teal
  '#b07a45', // golden brown
  '#6b8a6b', // forest green
];
