# Request for Creative Vision

## Context
We're designing a playback preparation system for a streaming music TUI client.

## Current Constraints (Things We're Struggling With)
1. Trying to generalize YouTube's workflow (extract → cache → concat)
2. AudioStore trait conflates storage/fetching/caching/artifact-type
3. Oscillating between Pipeline vs Pool+Orchestrator vs Decorators
4. Can't find abstractions that feel natural for YouTube AND Spotify AND Local

## What We Know Works (From Experience)
- Decorator pattern for Extractor (CachedExtractor, FallbackExtractor)
- Intent-driven API (PlayIntent describes what, not how)
- Trait-based extensibility (community can implement)

## What We're Asking
Think COMPLETELY outside the box. Forget our proposed designs.

If you were designing a streaming music playback system from scratch:
1. What PHILOSOPHY would guide it?
2. What are the UNIVERSAL TRUTHS about audio playback across all sources?
3. What abstractions would emerge NATURALLY from those truths?
4. How would it handle YouTube, Spotify, Local files WITHOUT special-casing?

## Constraints for Your Vision
- Must support: fastest time-to-first-audio + gapless playback
- Must be: loosely coupled, community extensible, configurable
- Must feel: intuitive (a new developer can understand in 5 minutes)

## Format
Give us:
1. A guiding philosophy (1-2 sentences)
2. The core abstractions (names + one-line descriptions)
3. How they compose (diagram)
4. How each backend (YouTube, Spotify, Local) maps to these abstractions
5. What insights we should take away
