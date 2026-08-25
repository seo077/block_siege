export { verifyCoreStateBoundary } from '../architecture/verify_core_state_boundary.mjs';
import { main } from '../architecture/verify_core_state_boundary.mjs';

main().catch(error => { console.error(error.message); if (error.report) console.error(JSON.stringify(error.report, null, 2)); process.exitCode = 1; });
