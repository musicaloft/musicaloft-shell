fn main() {
    let text = "crane builds every workspace member";
    println!("{} words", workspace_core::word_count(text));
}
