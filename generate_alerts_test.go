package main

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

// TestHelloName calls greetings.Hello with a name, checking
// for a valid return value.
func TestAvroDeserialization(t *testing.T) {
	_, err := loadAvroFile("testdata/avro/01a59897o0020c_000002.avro")
	if err != nil {
		t.Fatal(err)
	}
	assert.NoError(t, err)
	/*
		gen, err := generateAlert("01a59897o0020c_000002", "testdata", "0.1", "tes")
		if err != nil {
			t.Fatal(err)
		}

		if !reflect.DeepEqual(obj, gen) {
			t.Errorf("Expected %v, actual %v\n", obj, gen)
			t.FailNow()
		}
	*/
}
