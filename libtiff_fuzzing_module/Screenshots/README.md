# Notes About Summary Stats Screenshot


⚠️ Total Run Time is MISLEADING and INACCURATE



Reason 1:
The value is the sum of the run time across all 20 fuzzers, not the actual wall-clock elapsed time. For example, if each of the 20 fuzzers runs for 1 hour, the summary may show 20 hours.

Reason 2:
Suspending the virtual machine and resuming it later (for example, the next day) can incorrectly increase the reported total run time by adding idle time when fuzzing was not actually running.
