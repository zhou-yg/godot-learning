using Godot;
using System;

public partial class Player: Area2D {
	[Export]
	public int Speed { get; set; } = 200; // How fast the player will move (pixels/sec).
	[Export]
	public int Speed2 { get; set; } = 400; // How fast the player will move (pixels/sec).

	public Vector2 ScreenSize; // Size of the game window.
}
