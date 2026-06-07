using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;

namespace VoiceBridgeAI;

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
        {
            if (e.ExceptionObject is Exception ex)
            {
                StartupDiagnostics.Log("AppDomain.UnhandledException", ex);
            }
        };

        try
        {
            WinRT.ComWrappersSupport.InitializeComWrappers();
            Application.Start(_ =>
            {
                var queue = DispatcherQueue.GetForCurrentThread();
                if (queue is not null)
                {
                    SynchronizationContext.SetSynchronizationContext(
                        new DispatcherQueueSynchronizationContext(queue));
                }

                new App();
            });
        }
        catch (Exception ex)
        {
            StartupDiagnostics.Log(
                "Application.Start failed. Run desktop\\windows\\install-runtime.ps1 once, then retry.",
                ex);
            Environment.Exit(1);
        }
    }
}
