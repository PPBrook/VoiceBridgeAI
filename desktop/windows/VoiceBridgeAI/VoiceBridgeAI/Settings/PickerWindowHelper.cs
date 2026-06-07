using Microsoft.UI.Xaml;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace VoiceBridgeAI.Settings;

public static class PickerWindowHelper
{
    public static async Task<string?> PickFolderAsync(Window window, string? suggestedPath = null)
    {
        var picker = new FolderPicker
        {
            SuggestedStartLocation = PickerLocationId.DocumentsLibrary,
        };
        picker.FileTypeFilter.Add("*");
        Initialize(picker, window);

        if (!string.IsNullOrWhiteSpace(suggestedPath) && Directory.Exists(suggestedPath))
        {
            picker.SuggestedStartLocation = PickerLocationId.ComputerFolder;
        }

        var folder = await picker.PickSingleFolderAsync();
        return folder?.Path;
    }

    public static async Task<string?> PickTranscriptFileAsync(Window window, string? suggestedDirectory = null)
    {
        var picker = new FileOpenPicker
        {
            SuggestedStartLocation = PickerLocationId.DocumentsLibrary,
        };
        picker.FileTypeFilter.Add(".txt");
        picker.FileTypeFilter.Add(".md");
        Initialize(picker, window);

        if (!string.IsNullOrWhiteSpace(suggestedDirectory) && Directory.Exists(suggestedDirectory))
        {
            picker.SuggestedStartLocation = PickerLocationId.ComputerFolder;
        }

        var file = await picker.PickSingleFileAsync();
        return file?.Path;
    }

    private static void Initialize(object picker, Window window)
    {
        var hwnd = WindowNative.GetWindowHandle(window);
        InitializeWithWindow.Initialize(picker, hwnd);
    }
}
