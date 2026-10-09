import { JobQueueManager } from '../src/orchestration/jobQueue.ts';
import { RAMDetector } from '../src/inference/ramDetector.ts';
import { QuizRepository } from '../src/storage/database/quizRepository.ts';

async function main() {
  console.log('----------------------------------------------------');
  console.log('🤖 Local AI Quiz App - Backend Test Execution');
  console.log('----------------------------------------------------');

  // 1. Detect RAM & Tier
  const ramInfo = await RAMDetector.getRAMInfo();
  console.log(`📱 System RAM: ${ramInfo.totalRAMMB} MB | Tier: ${ramInfo.tier.toUpperCase()}`);
  console.log(`🎯 Recommended Model: ${ramInfo.recommendedModelId}`);
  console.log('----------------------------------------------------');

  // 2. Run Job Queue Generation Test
  console.log('⚙️ Starting Quiz Generation Job...');

  const sampleStudyText = `
  Photosynthesis is the process used by plants, algae, and certain bacteria to harness energy from sunlight and turn it into chemical energy.
  The process takes place primarily in the chloroplasts of plant cells using the green pigment chlorophyll.
  During photosynthesis, carbon dioxide and water are converted into glucose (sugar) and oxygen gas.
  The overall chemical equation is: 6CO2 + 6H2O + Light Energy -> C6H12O6 + 6O2.
  Photosynthesis is vital for life on Earth as it provides oxygen for aerobic organisms and serves as the primary source of organic matter for ecosystems.
  `;

  try {
    const generatedQuiz = await JobQueueManager.startQuizGenerationJob(
      {
        title: 'Photosynthesis Fundamentals',
        sourceText: sampleStudyText,
        totalQuestions: 3,
        difficulty: 'medium',
        allowedQuestionTypes: ['multiple_choice', 'true_false'],
      },
      (progress) => {
        console.log(`[${progress.percentage}%] Step: ${progress.step} - ${progress.message}`);
      }
    );

    console.log('\n----------------------------------------------------');
    console.log('✅ Quiz Generation Complete & Saved!');
    console.log(`ID: ${generatedQuiz.id}`);
    console.log(`Title: ${generatedQuiz.title}`);
    console.log(`Total Questions: ${generatedQuiz.totalQuestions}`);
    console.log('----------------------------------------------------');

    // Print Questions
    generatedQuiz.questions?.forEach((q, index) => {
      console.log(`\nQ${index + 1} (${q.questionType}): ${q.questionText}`);
      q.options.forEach((opt, oIdx) => {
        console.log(`   [${opt.isCorrect ? '✓' : ' '}] ${String.fromCharCode(65 + oIdx)}. ${opt.optionText}`);
      });
      console.log(`💡 Explanation: ${q.explanation}`);
    });
    console.log('----------------------------------------------------');
  } catch (err: any) {
    console.error('❌ Generation Error:', err.message);
  }
}

main();
