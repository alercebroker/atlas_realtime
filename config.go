package main

import (
  "encoding/json"
  "io/ioutil"
)

// Configuration struct
type Configuration struct {
  DataDirectory     string
  SchemaFile        string
}

/*
* loadConfiguration receives the path to a configuration file and returns
* a Configuration instance that contains the values of the file.
*/
func loadConfiguration(filename string) (Configuration, error) {
    bytes, err := ioutil.ReadFile(filename)
    if err != nil {
        return Configuration{}, err
    }
    var c Configuration
    err = json.Unmarshal(bytes, &c)
    if err != nil {
        return Configuration{}, err
    }
    return c, nil
}
