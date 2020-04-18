package main

import (
        "fmt"
        "os"
        "os/exec"
)

func main() {
        fmt.Print("Trimming...\n")
        if err := exec.Command("./trim").Run(); err != nil {
                fmt.Printf("Error encountered while trimming: %v", err)
                os.Exit(1)
        }

        fmt.Printf("Trim successful\n\n")

        fmt.Print("Sorting XCode project...\n")
        if err := exec.Command("xunique", "-s", "Fleet.xcodeproj").Run(); err != nil {
                fmt.Printf("Error encountered while sorting: %v", err)
                os.Exit(1)
        }

        fmt.Print("Sorting successful\n\n")
        fmt.Print("Sweep complete")
}
