# test

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason why this repo is public is because GitHub requires it.

Executes solution/repository unit tests.

## Examples

**Run neonCLOUD tests:**
```
# Run the tests:

- id: test
  uses: nforgeio-actions/test@master
  with:
    repo: neonCLOUD
    results-folder: ${{ github.workspace }}/test.log

# Fail the worklow when any tests failed.

- uses: nforgeio-actions/fail@master
  if: ${{ always() }}
  with:
    fail: ${{ !steps.test.outputs.success }}
    message: "One or more tests failed!"
```

**Run neonKUBE tests, adding timing and teams notification**
```
# Initializes environment variables including obtaining secrets from
# 1Password using DEVBOT's master password passed as a GitHub Secret.

- id: environment
  uses: nforgeio-actions/environment@master
  with:
    master-password: ${{ secrets.DEVBOT_MASTER_PASSWORD }}

# Capture the test start timestamp

- id: start-test-timestamp
  uses: nforgeio-actions/timestamp@master
  if: ${{ always() }}

# Run the tests

- id: test
  uses: nforgeio-actions/test@master
  if: ${{ steps.build.outputs.success == 'true' }}
  with:
    repo: neonCLOUD
    results-folder: ${{ github.workspace }}/${{ env.test-results-folder }}

# Capture the test end timestamp

- id: finish-test-timestamp
  uses: nforgeio-actions/timestamp@master
  if: ${{ always() }}

# Upload the test logs as workflow artifacts.
     
- id: upload-test-log
  uses: actions/upload-artifact@v2
  if: ${{ steps.build.outputs.success == 'true' }}
  with:
    name: test-results
    path: ${{ github.workspace }}/${{ env.test-results-folder }}/*.md

# Fail the worklow when any tests failed.

- uses: nforgeio-actions/fail@master
  if: ${{ always() }}
  with:
    fail: ${{ !steps.test.outputs.success }}
    message: "One or more tests failed!"

# Send the test notification to Teams

- id: teams-test-notification
  uses: nforgeio-actions/teams-notify-test@master
  if: ${{ always() }}
  with:
    channel: ${{ steps.environment.outputs.TEAM_DEVOPS_CHANNEL }}
    start-time: ${{ steps.start-test-timestamp.outputs.value }}
    finish-time: ${{ steps.finish-test-timestamp.outputs.value }}
    build-branch: ${{ steps.build.outputs.build-branch }}
    build-commit: ${{ steps.build.outputs.build-commit }}
    build-commit-uri: ${{ steps.build.outputs.build-commit-uri }}
    test-summary: ${{ env.test-summary }}
    test-outcome: ${{ steps.test.outcome }}
    test-success: ${{ steps.test.outputs.success }}
    test-result-uris: ${{ steps.test.outputs.result-uris }}
    workflow-ref: ${{ env.workflow-ref }}
    send-on: always
```
