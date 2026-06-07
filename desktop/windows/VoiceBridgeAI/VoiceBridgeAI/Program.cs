using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.Windows.ApplicationModel.DynamicDependency;

namespace VoiceBridgeAI;

public static class Program
{
    private const uint WindowsAppRuntimeVersion = 0x00010006; // 1.6

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
            Bootstrap.Initialize(WindowsAppRuntimeVersion);
        }
        catch (Exception ex)
        {
            StartupDiagnostics.Log(
                "Bootstrap.Initialize failed - install Windows App Runtime 1.6 (x64)",
                ex);
            Environment.Exit(1);
            return;
        }

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
            StartupDiagnostics.Log("Application.Start", ex);
            Environment.Exit(1);
        }
        finally
        {
            try
            {
                Bootstrap.Shutdown();
            }
            catch
            {
            }
        }
    }
}
