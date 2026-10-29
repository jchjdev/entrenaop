import { exerciseVideoConfig } from "../_shared/exercise_video_config.ts";
import { handleMediaCleanup } from "../_shared/media_cleanup.ts";

Deno.serve((request) => handleMediaCleanup(request, exerciseVideoConfig()));
