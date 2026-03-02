export interface WordNode {
  id: string;
  label: string; // 雙語, e.g. "哺乳類 mammal"
  parentId: string | null;
  depth: number;
  children: string[];
}

export interface EmbeddedNode extends WordNode {
  px: number; // Poincaré x coordinate [-1, 1]
  py: number; // Poincaré y coordinate [-1, 1]
}

export type SelectedIds = [string | null, string | null];
