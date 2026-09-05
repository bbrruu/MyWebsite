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

// 成員色：必須八個彼此可分辨（那是功能），但整體往冷偏以配合霧色調。
export const MEMBER_COLORS = [
  '#4e8496', // 主視覺藍綠
  '#5d7a63', // 冷苔綠
  '#5a5f8c', // 板岩紫
  '#a2585c', // 灰調紅
  '#7d86b8', // 主視覺紫
  '#3f7f85', // 深青
  '#8a6a4a', // 沙褐（全站唯一的暖）
  '#6d858d', // 藍灰
];
