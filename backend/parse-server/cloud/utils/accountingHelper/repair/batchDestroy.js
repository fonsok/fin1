'use strict';

async function destroyAllInBatches(objects) {
  if (!objects || objects.length === 0) return 0;
  // Parse REST destroyAll handles arrays > 50; we batch defensively.
  const BATCH = 50;
  let removed = 0;
  for (let i = 0; i < objects.length; i += BATCH) {
    const slice = objects.slice(i, i + BATCH);
    await Parse.Object.destroyAll(slice, { useMasterKey: true });
    removed += slice.length;
  }
  return removed;
}

module.exports = {
  destroyAllInBatches,
};
