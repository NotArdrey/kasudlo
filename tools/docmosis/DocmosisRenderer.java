import com.docmosis.SystemManager;
import com.docmosis.document.DocumentProcessor;
import com.docmosis.document.ExternalResourcePermissions;
import com.docmosis.template.population.DataProviderBuilder;
import com.docmosis.util.Configuration;

import java.io.File;
import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Properties;

public final class DocmosisRenderer {
  private DocmosisRenderer() {}

  public static void main(String[] args) throws Exception {
    if (args.length != 3) {
      throw new IllegalArgumentException(
          "Usage: DocmosisRenderer <template.docx> <output.docx> <data.json>");
    }

    File templateFile = new File(args[0]);
    File outputFile = new File(args[1]);
    File dataFile = new File(args[2]);

    if (!templateFile.isFile()) {
      throw new IllegalArgumentException("Template not found: " + templateFile.getAbsolutePath());
    }
    if (!dataFile.isFile()) {
      throw new IllegalArgumentException("JSON data not found: " + dataFile.getAbsolutePath());
    }

    Configuration configuration = configureDocmosis();

    String json = new String(Files.readAllBytes(dataFile.toPath()), StandardCharsets.UTF_8);
    DataProviderBuilder dataProviderBuilder = new DataProviderBuilder();
    dataProviderBuilder.addJSONString(json);

    boolean initialized = false;
    try {
      SystemManager.initialise(configuration);
      initialized = true;
      DocumentProcessor.renderDoc(
          templateFile,
          outputFile,
          dataProviderBuilder.getDataProvider(),
          ExternalResourcePermissions.NONE);
    } finally {
      if (initialized) {
        SystemManager.release();
      }
    }
  }

  private static Configuration configureDocmosis() throws Exception {
    Properties properties = new Properties();
    File propertiesFile = new File("tools/docmosis/docmosis.properties");
    if (propertiesFile.isFile()) {
      try (FileInputStream input = new FileInputStream(propertiesFile)) {
        properties.load(input);
      }
    }

    applyProperty("docmosis.key", "DOCMOSIS_KEY", properties);
    applyProperty("docmosis.site", "DOCMOSIS_SITE", properties);

    for (String name : properties.stringPropertyNames()) {
      if (name.startsWith("docmosis.") && System.getProperty(name) == null) {
        System.setProperty(name, properties.getProperty(name));
      }
    }

    if (isBlank(System.getProperty("docmosis.key"))) {
      throw new IllegalStateException(
          "Missing docmosis.key. Add it to tools/docmosis/docmosis.properties or DOCMOSIS_KEY.");
    }
    if (isBlank(System.getProperty("docmosis.site"))) {
      throw new IllegalStateException(
          "Missing docmosis.site. Add it to tools/docmosis/docmosis.properties or DOCMOSIS_SITE.");
    }

    Configuration configuration = Configuration.standard();
    configuration.setKeyAndSite(
        System.getProperty("docmosis.key"),
        System.getProperty("docmosis.site"));

    String officeLocation = firstNonBlank(
        System.getenv("DOCMOSIS_OFFICE_LOCATION"),
        properties.getProperty("docmosis.openoffice.location"),
        properties.getProperty("docmosis.office.location"),
        System.getenv("LIBREOFFICE_HOME"),
        "E:\\Tools\\LibreOffice");
    configuration.setOfficeLocation(officeLocation);

    return configuration;
  }

  private static void applyProperty(String propertyName, String environmentName, Properties properties) {
    if (!isBlank(System.getProperty(propertyName))) {
      return;
    }

    String environmentValue = System.getenv(environmentName);
    if (!isBlank(environmentValue)) {
      System.setProperty(propertyName, environmentValue);
      return;
    }

    String propertyValue = properties.getProperty(propertyName);
    if (!isBlank(propertyValue)) {
      System.setProperty(propertyName, propertyValue);
    }
  }

  private static boolean isBlank(String value) {
    return value == null || value.trim().isEmpty();
  }

  private static String firstNonBlank(String... values) {
    for (String value : values) {
      if (!isBlank(value)) {
        return value;
      }
    }
    return null;
  }
}
