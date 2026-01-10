using Godot;
using System;
using System.Collections.Generic;

public partial class AgentManager : Node
{
	/* ==============================
	 * SIGNALS
	 * ============================== */

	[Signal]
	public delegate void ChatResponseEventHandler(string text);

	[Signal]
	public delegate void SystemMessageEventHandler(string text);

	/* ==============================
	 * STATE
	 * ============================== */

	private List<string> _chatHistory = new();
	private List<string> _consoleHistory = new();

	/* ==============================
	 * GODOT LIFECYCLE
	 * ============================== */

	public override void _Ready()
	{
		GD.Print("[AgentManager] Ready");

		if (HasNode("/root/SystemConsole"))
		{
			GD.Print("[AgentManager] Connecting to SystemConsole");
			var console = GetNode<SystemConsole>("/root/SystemConsole");
			console.ConsoleOutputReceived += OnConsoleOutput;
		}
		else
		{
			GD.Print("[AgentManager] SystemConsole not found");
		}
	}

	/* ==============================
	 * ENTRY POINT (CHAT UI)
	 * ============================== */

	public void SubmitChat(string text)
	{
		GD.Print("[AgentManager] SubmitChat: ", text);

		RegisterUserMessage(text);
		string context = BuildContext();
		DispatchToLLM(context);
	}

	/* ==============================
	 * CONSOLE HOOK
	 * ============================== */

	private void OnConsoleOutput(string text)
	{
		GD.Print("[AgentManager] Console output received");
		_consoleHistory.Add(text);
	}

	/* ==============================
	 * INTERNAL PIPELINE
	 * ============================== */

	private void RegisterUserMessage(string text)
	{
		GD.Print("[AgentManager] Registering user message");
		_chatHistory.Add(text);
	}

	private string BuildContext()
	{
		GD.Print("[AgentManager] Building context");

		List<string> parts = new();

		if (_chatHistory.Count > 0)
		{
			parts.Add("[chat]");
			parts.AddRange(_chatHistory);
			parts.Add("[/chat]");
		}

		if (_consoleHistory.Count > 0)
		{
			parts.Add("[console]");
			parts.AddRange(_consoleHistory);
			parts.Add("[/console]");
		}

		string context = string.Join("\n", parts);
		GD.Print("[AgentManager] Context length: ", context.Length);

		return context;
	}

	private void DispatchToLLM(string context)
	{
		GD.Print("[AgentManager] Dispatching to LLM");

		if (!HasNode("/root/LLM"))
		{
			GD.Print("[AgentManager] ERROR: LLM not available");
			EmitSignal(SignalName.SystemMessage, "LLM not available");
			return;
		}

		var llm = GetNode<LLM>("/root/LLM");
		llm.Prompt(context, OnLLMResponse);
	}

	private void OnLLMResponse(string text)
	{
		GD.Print("[AgentManager] LLM response received");
		RouteResponseToChat(text);
	}

	private void RouteResponseToChat(string text)
	{
		GD.Print("[AgentManager] Routing response to chat");
		EmitSignal(SignalName.ChatResponse, text);
	}
}
