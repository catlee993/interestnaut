package bindings

import (
	"strings"
	"unicode"
)

// normalizeString normalizes a string by converting to lowercase and removing non-alphanumeric characters
func normalizeString(s string) string {
	// Convert to lowercase
	s = strings.ToLower(s)

	// Remove punctuation and special characters
	var result strings.Builder
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsNumber(r) || unicode.IsSpace(r) {
			result.WriteRune(r)
		}
	}

	// Remove extra spaces
	return strings.Join(strings.Fields(result.String()), " ")
}

// levenshteinDistance calculates the Levenshtein distance between two strings
func levenshteinDistance(s1, s2 string) int {
	s1 = normalizeString(s1)
	s2 = normalizeString(s2)

	len1 := len(s1)
	len2 := len(s2)

	// Create a 2D array to store distances
	matrix := make([][]int, len1+1)
	for i := range matrix {
		matrix[i] = make([]int, len2+1)
	}

	// Initialize the first row and column
	for i := 0; i <= len1; i++ {
		matrix[i][0] = i
	}
	for j := 0; j <= len2; j++ {
		matrix[0][j] = j
	}

	// Fill in the rest of the matrix
	for i := 1; i <= len1; i++ {
		for j := 1; j <= len2; j++ {
			if s1[i-1] == s2[j-1] {
				matrix[i][j] = matrix[i-1][j-1]
			} else {
				matrix[i][j] = findMin(
					matrix[i-1][j]+1,   // deletion
					matrix[i][j-1]+1,   // insertion
					matrix[i-1][j-1]+1, // substitution
				)
			}
		}
	}

	return matrix[len1][len2]
}

// findMin returns the minimum of three integers
func findMin(a, b, c int) int {
	if a <= b && a <= c {
		return a
	}
	if b <= a && b <= c {
		return b
	}
	return c
}

// findMax returns the maximum of two integers
func findMax(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// calculateSimilarity calculates the similarity between two strings using Levenshtein distance
func calculateSimilarity(s1, s2 string) float64 {
	distance := levenshteinDistance(s1, s2)
	maxLen := findMax(len(normalizeString(s1)), len(normalizeString(s2)))
	if maxLen == 0 {
		return 1.0
	}
	return 1.0 - float64(distance)/float64(maxLen)
}
