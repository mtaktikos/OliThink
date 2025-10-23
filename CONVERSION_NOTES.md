# Conversion to 10×8 Board - Technical Notes

## Summary
This document describes the work needed to fully convert OliThink from an 8×8 (64-square) chess engine to a 10×8 (80-square) chess variant engine with the Commoner piece.

## Requirements
1. Board: 10 columns (files a-j) × 8 ranks → 80 squares total
2. Starting position: `rgnbkqbn1r/pppppppppp/10/10/10/10/PPPPPPPPPP/R1NBQKBNGR w - - 0 1`
3. Promotion zones: White promotes on rank 8 (a8-j8), Black on rank 1 (a1-j1)
4. Commoner piece (G): Moves like a King but is not royal and can be captured

## Work Completed

### ✅ Basic Setup
- Added COMMONER piece type (code 8, value 290 centipawns)
- Updated pieceChar array to include 'G'
- Updated piece value and tracking arrays
- Set new default FEN string

### ✅ Coordinate System
- Added board dimension constants (BOARD_FILES=10, BOARD_WIDTH=10, BOARD_SQUARES=80)
- Updated SQUARE macro: `rank*10 + file`
- Updated RANK macro to work with new coordinates
- Updated file/rank extraction throughout code

### ✅ Move Notation
- FEN parsing handles '10' for empty squares
- FEN parsing handles files a-j
- En passant parsing handles files a-j
- Move display shows files a-j (e.g., "e1e2", "i7i8")
- Move parsing accepts files a-j
- ISFILE macro updated to accept a-j

### ✅ Move Generation Updates
- Knight move offsets updated for 10-wide board: {-21,-19,-12,-8,8,12,19,21}
- King move offsets updated: {-11,-10,-9,-1,1,9,10,11}
- Pawn initialization updated for 10-wide board
- Pawn move generation updated (forward moves, captures, double moves)
- Commoner move generation added (moves like King)
- Commoner attack/defense calculations added
- Knight and King initialization updated

### ✅ Promotion
- Promotion zone checks updated: White on rank 7, Black on rank 0
- Pawn double-move logic updated

## 🚨 Critical Remaining Work

### The Fundamental Problem: Bitboard Size Limitation

**The core issue:** OliThink uses 64-bit integers (u64) for bitboards, where each bit represents one square. For an 8×8 board, 64 bits = 64 squares is perfect. For a 10×8 board with 80 squares, we need 80 bits, which doesn't fit in a u64.

**Current state:** 
- `u64 pieceb[9]` - piece bitboards (one per piece type)
- `u64 colorb[2]` - color bitboards (white/black)
- All bitboard operations assume 64 bits

**Impact:** Squares 64-79 cannot be properly represented. Any piece on these squares will overflow or be ignored.

### Required Changes

#### 1. Extend Bitboard Type (Major Architectural Change)

Option A: Use two u64 values per bitboard
```c
typedef struct {
    u64 low;   // bits 0-63 (squares 0-63)
    u64 high;  // bits 64-127 (squares 64-79 used)
} bb_t;
```

Then change:
- `u64 pieceb[9]` → `bb_t pieceb[9]`
- `u64 colorb[2]` → `bb_t colorb[2]`

Option B: Use u128 (if available on platform)

Option C: Complete rewrite using array-based piece tracking instead of bitboards

#### 2. Update All Bitboard Operations (Hundreds of Changes)

Every bitboard operation needs updating:
- `TEST(f, bitboard)` - check if square f is set
- `setBit(f, bitboard)` - set square f
- `xorBit(f, bitboard)` - toggle square f
- `BIT[f]` - bitmask for square f (currently 1LL << f, fails for f >= 64)
- Bitwise operations: &, |, ^, ~
- `pullLsb(&bitboard)` - extract and remove least significant bit
- `bitcnt(bitboard)` - count set bits

Each needs to handle the split between low and high components.

#### 3. Update Sliding Piece Move Generation

The ray-based move generation for bishops, rooks, and queens uses complex bit manipulation:
- `RATT1`, `RATT2` - rook attack tables
- `BATT3`, `BATT4` - bishop attack tables
- `key000`, `key090`, `key045`, `key135` - attack key generation
- `rays[]` array and initialization

These all assume 8×8 board geometry and need complete reimplementation for 10×8.

#### 4. Update Attack/Defense Ray Calculations

Functions like `_rook0`, `_rook90`, `_bishop45`, `_bishop135` generate attack rays. These use hardcoded assumptions about 8-wide boards (e.g., `i%8` for file, `i&56` for rank).

#### 5. Update Castling

Castling code has hardcoded square numbers:
- White king on square 4 → needs to be e1 = rank 0 * 10 + 4 = 4 (coincidentally same!)
- White rooks on squares 0, 7 → need to be a1 = 0, but where does the other rook go?
- The FEN shows no castling rights, so this might not be needed

#### 6. Update Evaluation

The evaluation function accesses piece positions and needs to work with extended bitboards.

### Implementation Estimate

This is essentially a **complete rewrite** of the engine core:
- ~100+ references to pieceb[] and colorb[] to change
- All bitboard helper macros and functions
- Move generation for all piece types
- Attack/defense calculations
- Hash table key generation
- And more...

**Estimated effort:** 20-40 hours for an experienced chess engine programmer

## Testing Strategy

1. Start with simple positions (just kings)
2. Add one piece type at a time
3. Verify move generation for each piece type
4. Test promotions
5. Test Commoner as non-royal piece
6. Run perft tests to verify move generation accuracy

## Alternative Approach: Simpler But Less Efficient

Instead of full bitboard rewrite, use hybrid approach:
1. Keep main bitboards as u64 for squares 0-63
2. Add separate small bitsets or arrays for squares 64-79
3. Update all operations to check both

This would be less elegant but might be faster to implement.

## Conclusion

The conversion from 8×8 to 10×8 is not a "small change" - it requires fundamental architectural changes to how the engine represents the board. The current implementation has laid the groundwork (coordinates, notation, piece definitions) but the bitboard representation is the critical blocker to full functionality.
