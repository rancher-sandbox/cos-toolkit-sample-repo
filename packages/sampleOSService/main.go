//some http server code here

package main

import (
    "io"
    "fmt"
    "net/http"
    "os/exec"
)

func hello(w http.ResponseWriter, req *http.Request) {

    fmt.Fprintf(w, "hello\n")
}

func headers(w http.ResponseWriter, req *http.Request) {

    for name, headers := range req.Header {
        for _, h := range headers {
            fmt.Fprintf(w, "%v: %v\n", name, h)
        }
    }
}

func fortune(w http.ResponseWriter, req *http.Request) {
    cmd := exec.Command("fortune")
    stdout, _ := cmd.Output()
    fmt.Fprintf(w, string(stdout))
}

func fortuneteller(w http.ResponseWriter, req *http.Request) {
    cmd := exec.Command("fortune")
    stdout, _ := cmd.Output()

    cmd = exec.Command("cowsay")
    stdin, _ := cmd.StdinPipe()

    go func() {
        defer stdin.Close()
        io.WriteString(stdin, string(stdout))
    }()

    out, _ := cmd.CombinedOutput()
    fmt.Fprintf(w, string(out))
}

func main() {

    http.HandleFunc("/hello", hello)
    http.HandleFunc("/headers", headers)
    http.HandleFunc("/fortune", fortune)
    http.HandleFunc("/fortuneteller", fortuneteller)

    http.ListenAndServe(":8090", nil)
}
