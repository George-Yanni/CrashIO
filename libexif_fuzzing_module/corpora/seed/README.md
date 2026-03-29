# Seed images

This module uses the **`jpg/`** tree from the [exif-samples](https://github.com/ianare/exif-samples) collection (fetched into `third_party/` by `scripts/fetch_sources.sh`).

Populate `corpora/in/` before fuzzing:

```bash
./scripts/prepare_corpus.sh
```

Or copy a subset of `third_party/exif-samples-master/jpg/*.jpg` into `corpora/in/` yourself.
