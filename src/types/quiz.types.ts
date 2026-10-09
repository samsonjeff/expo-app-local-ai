export type QuestionType = 
  | 'multiple_choice'
  | 'true_false'
  | 'fill_in_blank'
  | 'enumeration'
  | 'essay'
  | 'identification';

export type QuizDifficulty = 'easy' | 'medium' | 'hard' | 'mixed';

export interface QuizOption {
  id: string;
  questionId: string;
  optionText: string;
  isCorrect: boolean;
  orderIndex: number;
}

export interface QuizQuestion {
  id: string;
  quizId: string;
  questionText: string;
  questionType: QuestionType;
  points: number;
  explanation: string;
  orderIndex: number;
  options: QuizOption[];
  // For fill-in-the-blank, essay, or identification questions where option list might be empty:
  acceptableAnswers?: string[];
}

export interface Quiz {
  id: string;
  title: string;
  description: string;
  category: string;
  difficulty: QuizDifficulty;
  questionTypes: QuestionType[];
  totalQuestions: number;
  sourceType: 'text' | 'document' | 'topic';
  sourceFilename?: string;
  createdAt: string; // ISO Date string
  updatedAt: string; // ISO Date string
  questions?: QuizQuestion[];
}

export interface AttemptAnswer {
  id: string;
  attemptId: string;
  questionId: string;
  selectedOptionId?: string;
  textResponse?: string;
  isCorrect: boolean;
  pointsEarned: number;
}

export interface QuizAttempt {
  id: string;
  quizId: string;
  score: number;
  maxScore: number;
  percentage: number;
  completedAt: string;
  durationSeconds: number;
  answers?: AttemptAnswer[];
}

export interface QuizGenerationRequest {
  title?: string;
  sourceText?: string;
  documentId?: string;
  topic?: string;
  totalQuestions: number;
  difficulty: QuizDifficulty;
  allowedQuestionTypes: QuestionType[];
  targetAudience?: string;
  additionalInstructions?: string;
}
