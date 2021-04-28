# test

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason why this repo is public is because GitHub requires it.

Executes solution/repository unit tests.

## Examples

**Run neonCLOUD unit tests:**
```
- id: test
  uses: nforgeio-actions/test@master
  with:
    repo: neonCLOUD
    results-folder: ${{ github.workspace }}/test.log
```
