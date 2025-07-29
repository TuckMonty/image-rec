import React from "react";
import { Input, Button, Text, Box } from "@chakra-ui/react";

export default function ImageUploadInput({ id, onChange, file, multiple = true, accept = "image/*", buttonLabel = "Select Image", changeLabel = "Change Image", ...props }) {
  return (
    <Box mb={2}>
      <Input
        id={id}
        type="file"
        accept={accept}
        multiple={multiple}
        display="none"
        onChange={onChange}
        {...props}
      />
      <Button
        as="label"
        htmlFor={id}
        colorScheme="teal"
        variant="outline"
        mb={2}
        cursor="pointer"
      >
        {file ? changeLabel : buttonLabel}
      </Button>
      {file && (
        Array.isArray(file) ? (
          file.map((f, idx) => (
            <Text key={idx} ml={2} display="inline" fontSize="sm" color="gray.600">{f.name}</Text>
          ))
        ) : (
          <Text ml={2} display="inline" fontSize="sm" color="gray.600">{file.name}</Text>
        )
      )}
    </Box>
  );
}
