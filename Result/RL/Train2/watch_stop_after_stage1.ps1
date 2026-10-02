# Watcher of the Train2 run (started 2026-10-02): stops the MATLAB process of the run at the END of curriculum stage 1
# (after the 4th chunk = 40 episodes, the line "chunk 4 (stage 1)" in the progress log), after copying the agents of that moment:
#   agents\agent_stage1_last.mat  (agent after 40 episodes)   agents\agent_stage1_best.mat  (best validation cost so far)
# It stops only the process tree of the launcher PID given below (the Train2 run), never another MATLAB session.
# Why: the user asked to run the curriculum stage by stage and to stop, evaluate and adjust after every stage.
$launcherPid = 41480
$dir = 'C:\Users\Admin\OneDrive\Desktop\git\Adaptive-EPS-using-Reinforcement-Learning\Result\RL\Train2'
$log = Join-Path $dir 'RL_Train2_progress_log.txt'
$watchLog = Join-Path $dir 'watch_stop_after_stage1_log.txt'
function Say($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Out-File -Append -Encoding utf8 $watchLog }
Say "watcher started, launcher PID $launcherPid"
while ($true) {
    if (-not (Get-Process -Id $launcherPid -ErrorAction SilentlyContinue)) { Say 'launcher process is gone, watcher ends'; break }
    if ((Test-Path $log) -and (Select-String -Path $log -Pattern 'chunk 4 \(stage 1\)' -Quiet)) {
        Start-Sleep -Seconds 20      # let train_rl finish saving and plotting after the log line
        Copy-Item (Join-Path $dir 'agents\agent_last.mat') (Join-Path $dir 'agents\agent_stage1_last.mat') -Force
        Copy-Item (Join-Path $dir 'agents\agent_best.mat') (Join-Path $dir 'agents\agent_stage1_best.mat') -Force
        Copy-Item (Join-Path $dir 'RL_Train2_learning_curve.png') (Join-Path $dir 'RL_Train2_stage1_learning_curve.png') -Force
        taskkill /PID $launcherPid /T /F | Out-Null
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') STAGE 1 FINISHED: run stopped by the watcher; agents copied to agent_stage1_*.mat (stage 2 not started)" | Out-File -Append -Encoding utf8 $log
        Say 'stage 1 finished, agents copied, run stopped'
        break
    }
    Start-Sleep -Seconds 20
}
