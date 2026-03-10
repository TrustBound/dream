import ExampleImg from "@site/static/img/example.png";
import styles from "./styles.module.css";

export default function Example() {
  return (
    <div className={styles.example_code}>
      <img src={ExampleImg} alt="Example" />
    </div>
  );
}
