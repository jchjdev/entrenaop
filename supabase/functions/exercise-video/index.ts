import { exerciseVideoConfig } from "../_shared/exercise_video_config.ts";
import { handleExerciseVideo } from "../_shared/exercise_video.ts";
Deno.serve((request) => handleExerciseVideo(request, exerciseVideoConfig()));
