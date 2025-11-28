fn main() {
    println!("Hello from rust-example!");
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_example() {
        assert_eq!(2 + 2, 4);
    }
}
