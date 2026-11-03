import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  APPLICATION_ORDER_METADATA_FILE,
  APPLICATION_ORDER_MOONBIT_FILE,
  readApplicationOrderJson,
  readApplicationOrderLock,
  renderApplicationOrderMoonbit,
  writeApplicationOrderFile,
} from './application-order.mjs';

export function generateApplicationOrder() {
  const metadata = readApplicationOrderJson(APPLICATION_ORDER_METADATA_FILE);
  const lock = readApplicationOrderLock(metadata);
  writeApplicationOrderFile(APPLICATION_ORDER_MOONBIT_FILE, renderApplicationOrderMoonbit(lock));
  console.log(
    `Rendered ${lock.properties.length} typed and ${lock.supplementalProperties.length} supplemental application-order records from the committed lock (${lock.semanticsDigest}).`,
  );
  return lock;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    generateApplicationOrder();
  } catch (error) {
    console.error(error.stack ?? error);
    process.exitCode = 1;
  }
}
