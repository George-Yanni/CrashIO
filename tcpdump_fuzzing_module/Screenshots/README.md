# Notes About Summary Stats Screenshot

In the screenshot "Screenshot from 2026-04-02 10-25-25.png", the reported value:

- Total run time: 19 days, 2 hours

is not accurate.

Reason 1:
The value is the sum of the run time across all 20 fuzzers, not the actual wall-clock elapsed time. For example, if each of the 20 fuzzers runs for 1 hour, the summary may show 20 hours.

Reason 2:
Suspending the virtual machine and resuming it later (for example, the next day) can incorrectly increase the reported total run time by adding idle time when fuzzing was not actually running.
