using Godot;
using System;
using System.Text;
using System.Text.RegularExpressions;

public partial class WindowsConsoleTest : Node
{
	private RichTextLabel _output;
	private LineEdit _input;

	// ============================================================
	// Regexes compiled once (cheap + safe)
	// ============================================================

	// CSI: ESC [ parameters intermediates final-byte
	// Examples: ESC[2J, ESC[?25l, ESC[H
	private static readonly Regex _ansiCsiRegex = new(
		@"\x1B\[[0-9;?]*[ -/]*[@-~]",
		RegexOptions.Compiled
	);

	// OSC: ESC ] ... BEL  OR  ESC ] ... ESC \
	// Examples: ESC]0;titleBEL, ESC]9001;CmdNotFound;haloESC\
	private static readonly Regex _ansiOscRegex = new(
		@"\x1B\][^\x07]*(\x07|\x1B\\)",
		RegexOptions.Compiled
	);

	public override void _Ready()
	{   	
		_output = GetNode<RichTextLabel>("RichTextLabel");
		_input = GetNode<LineEdit>("LineEdit");

		_output.Clear();

		// Connect Enter key on LineEdit
		_input.TextSubmitted += OnInputSubmitted;

		// Subscribe to console output
		SystemConsole.Instance.ConsoleOutputReceived += OnConsoleOutput;
	}

	public override void _ExitTree()
	{
		// Clean unsubscribe (important)
		if (SystemConsole.Instance != null)
			SystemConsole.Instance.ConsoleOutputReceived -= OnConsoleOutput;
	}

	/* ============================================================
	   INPUT → CONSOLE
	   ============================================================ */

	private void OnInputSubmitted(string text)
	{
		if (string.IsNullOrWhiteSpace(text))
			return;

		SystemConsole.Instance.Send(text);

		_input.Clear();
		_input.GrabFocus();
	}

	/* ============================================================
	   CONSOLE → OUTPUT
	   ============================================================ */

	private void OnConsoleOutput(string text)
	{
		// Sanitize at the surface-most boundary:
		// - remove terminal control artefacts
		// - preserve all actual content verbatim
		string sanitized = SanitizeConsoleText(text);

		_output.AppendText(sanitized);
		GD.Print(sanitized);

		// Auto-scroll to bottom
		_output.ScrollToLine(_output.GetLineCount());
	}

	/* ============================================================
	   SANITIZATION
	   ============================================================ */

	private static string SanitizeConsoleText(string input)
	{
		if (string.IsNullOrEmpty(input))
			return input;

		// 1) Remove ANSI CSI sequences (cursor movement, colors, clears, etc.)
		string result = _ansiCsiRegex.Replace(input, string.Empty);

		// 2) Remove ANSI OSC sequences (window title, terminal protocol messages)
		result = _ansiOscRegex.Replace(result, string.Empty);

		// 3) Remove any remaining stray ESC characters
		//    (ESC alone is never valid printable content)
		result = result.Replace("\x1B", string.Empty);

		// NOTE:
		// - No trimming
		// - No newline normalization
		// - No whitespace collapsing
		// This guarantees the visible text remains untouched.

		return result;
	}
	public override void _Input(InputEvent @event)
	{
		// Only react to keyboard presses
		if (@event is not InputEventKey keyEvent)
			return;

		if (!keyEvent.Pressed || keyEvent.Echo)
			return;

		// Force focus BEFORE the engine dispatches the key
		if (_input != null && !_input.HasFocus())
		{
			_input.GrabFocus();
		}

		// IMPORTANT:
		// Do NOT mark the event as handled
		// Do NOT forward it manually
		// Let Godot deliver it to the focused LineEdit
	}
}
