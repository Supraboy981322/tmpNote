package main

import (
	"math/big"
	"crypto/rand"
)

//random password generator
func genId(l int64) string {
	charSet := []string{
		"a", "b",	"c", "d", "e", "f", "g",
		"h", "i", "j", "k", "l", "m", "n",
		"o", "p", "q", "r", "s", "t", "u",
		"v", "w", "x", "y", "z", "A", "B",
		"C", "D", "E", "F", "G", "H", "I",
		"J", "K", "L", "M", "N", "O", "P",
		"Q", "R", "S", "T", "U", "V", "W",
		"X", "Y", "Z", "0", "9", "8", "7",
		"6", "5", "4", "3", "2", "1",
	}

	//so I can import
	//  one less module
	if l < 0 {
		l = -l
	}

	//actually generate
	var res string
	var i int64
	for i = 0; i < l; i++ {
		//convert to big.Int (for crypto/rand) 
		bigInt := big.NewInt(int64(len(charSet)))

		//generate random integer
		in, err := rand.Int(rand.Reader, bigInt)
		if err != nil { return err.Error() }

		//convert to regular integer
		ranDig := int(in.Int64())

		//add char of random index
		//  to result
		res += charSet[ranDig]
	}

	//finally,
	//  return the result
	return res
}
